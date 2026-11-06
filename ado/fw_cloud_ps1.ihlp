# fw_cloud.ps1: Framework Cloud requests for Framework for Stata on Windows.
# Part of the framework package. It ships as an .ihlp file because net install
# keeps only Stata file types; Stata copies it to a .sh or .ps1 file to run it.
#
# Tokens never pass through Stata. This script reads them from the
# environment, the project's .env, Windows Credential Manager, or the token
# files that R, Python, and fw share, and hands them to curl.exe in a private
# header file.
#
#   fw_cloud.ps1 http   <curl.cfg> <project|user|none> <root> <host> <outdir>
#   fw_cloud.ps1 poll   <curl.cfg> <host> <server> <outdir>
#   fw_cloud.ps1 status <host>
#   fw_cloud.ps1 logout <host> <server> <outdir>
#   fw_cloud.ps1 check  <host> <server> <outdir>

$ErrorActionPreference = 'Stop'
$action = $args[0]

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class FwCred {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct CREDENTIAL {
        public int Flags; public int Type; public string TargetName; public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize; public IntPtr CredentialBlob; public int Persist;
        public int AttributeCount; public IntPtr Attributes; public string TargetAlias; public string UserName;
    }
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CredRead(string target, int type, int flags, out IntPtr cred);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CredWrite(ref CREDENTIAL cred, int flags);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CredDelete(string target, int type, int flags);
    [DllImport("advapi32.dll")]
    static extern void CredFree(IntPtr cred);
    public static string Read(string target) {
        IntPtr p;
        if (!CredRead(target, 1, 0, out p)) return null;
        try {
            CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
            byte[] blob = new byte[c.CredentialBlobSize];
            Marshal.Copy(c.CredentialBlob, blob, 0, c.CredentialBlobSize);
            // R's keyring and fw write UTF-8. Older writers used UTF-16.
            string s = Encoding.UTF8.GetString(blob);
            if (s.IndexOf('\0') >= 0) s = Encoding.Unicode.GetString(blob);
            return s;
        } finally { CredFree(p); }
    }
    public static bool Write(string target, string user, string secret) {
        byte[] blob = Encoding.UTF8.GetBytes(secret);
        CREDENTIAL c = new CREDENTIAL();
        c.Type = 1; c.TargetName = target; c.UserName = user; c.Persist = 2;
        c.CredentialBlobSize = blob.Length;
        c.CredentialBlob = Marshal.AllocHGlobal(blob.Length);
        try {
            Marshal.Copy(blob, 0, c.CredentialBlob, blob.Length);
            return CredWrite(ref c, 0);
        } finally { Marshal.FreeHGlobal(c.CredentialBlob); }
    }
    public static bool Delete(string target) { return CredDelete(target, 1, 0); }
}
"@

function CfgDir {
    if ($env:FW_CONFIG_HOME) { return $env:FW_CONFIG_HOME }
    if ($env:XDG_CONFIG_HOME) { return (Join-Path $env:XDG_CONFIG_HOME 'framework') }
    return (Join-Path $env:USERPROFILE '.config\framework')
}

function RCfgDir {
    if ($env:R_USER_CONFIG_DIR) { return (Join-Path $env:R_USER_CONFIG_DIR 'R\framework') }
    if ($env:XDG_CONFIG_HOME) { return (Join-Path $env:XDG_CONFIG_HOME 'R\framework') }
    return (Join-Path $env:APPDATA 'R\config\R\framework')
}

function TokName($h) {
    if ($h -eq 'framework.pub') { return 'cloud-token' }
    return 'cloud-token-' + ($h -replace '[^a-z0-9.-]', '_')
}

function FirstLine($f) {
    $l = Get-Content -LiteralPath $f -TotalCount 1
    if ($null -eq $l) { return '' }
    return $l.Trim()
}

function UserToken($h) {
    if ($env:FW_CLOUD_TOKEN) { return @($env:FW_CLOUD_TOKEN, 'environment') }
    if ($env:FW_TOKEN_FILE) {
        if (Test-Path -LiteralPath $env:FW_TOKEN_FILE) { return @((FirstLine $env:FW_TOKEN_FILE), 'file') }
        return @('', 'none')
    }
    $t = [FwCred]::Read(':framework-cloud:' + $h + ':token')
    if (-not $t -and $h -eq 'framework.pub') { $t = [FwCred]::Read(':framework.pub:token') }
    if ($t) { return @($t, 'keyring') }
    foreach ($d in @((CfgDir), (RCfgDir))) {
        $f = Join-Path $d (TokName $h)
        if (Test-Path -LiteralPath $f) { return @((FirstLine $f), 'file') }
    }
    if ($h -eq 'framework.pub') {
        $f = Join-Path $env:USERPROFILE '.secrets\framework\token'
        if (Test-Path -LiteralPath $f) { return @((FirstLine $f), 'file') }
    }
    return @('', 'none')
}

function ProjectToken($root) {
    if ($env:FW_PROJECT_TOKEN) { return $env:FW_PROJECT_TOKEN }
    $f = Join-Path $root '.env'
    if (-not (Test-Path -LiteralPath $f)) { return '' }
    $v = ''
    foreach ($line in Get-Content -LiteralPath $f) {
        if ($line -match '^\s*(export\s+)?FW_PROJECT_TOKEN\s*=\s*(.*)$') { $v = $Matches[2].Trim().Trim('"').Trim("'") }
    }
    return $v
}

function Utf8NoBom($path, $text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
}

function CurlWith($cfg, $tok, $out) {
    $curlArgs = @('-K', $cfg)
    $auth = Join-Path $out 'auth.cfg'
    if ($tok) {
        Utf8NoBom $auth ('header = "Authorization: Bearer ' + $tok + '"' + "`n")
        $curlArgs += @('-K', $auth)
    }
    try {
        & curl.exe @curlArgs 1> (Join-Path $out 'status.txt') 2> (Join-Path $out 'curl.err')
        return $LASTEXITCODE
    } finally {
        if (Test-Path -LiteralPath $auth) { Remove-Item -LiteralPath $auth -Force }
    }
}

function StoreToken($h, $tok) {
    if ($env:FW_TOKEN_FILE) {
        New-Item -ItemType Directory -Force -Path (Split-Path $env:FW_TOKEN_FILE) | Out-Null
        Utf8NoBom $env:FW_TOKEN_FILE ($tok + "`n")
        return 'file'
    }
    if ([FwCred]::Write(':framework-cloud:' + $h + ':token', 'token', $tok)) { return 'keyring' }
    $d = CfgDir
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Utf8NoBom (Join-Path $d (TokName $h)) ($tok + "`n")
    return 'file'
}

function MeConfig($server, $out) {
    $me = Join-Path $out 'me.json'
    $cfg = Join-Path $out 'me.cfg'
    Utf8NoBom $cfg ('url = "' + $server + '/api/v1/me"' + "`n" +
        'header = "Accept: application/json"' + "`n" +
        'user-agent = "framework-stata (fw_cloud.ps1)"' + "`n" +
        'output = "' + ($me -replace '\\', '/') + '"' + "`n" +
        'write-out = "%{http_code}"' + "`nsilent`nshow-error`nmax-time = 60`n")
    return $cfg
}

# Revoke a token on the server with DELETE /api/v1/token. True on 2xx, and
# on 401, which means the token was already invalid.
function RevokeToken($tok, $server, $out) {
    $cfg = Join-Path $out 'revoke.cfg'
    $body = Join-Path $out 'revoke.json'
    $text = 'url = "' + $server + '/api/v1/token"' + "`n" +
        'request = "DELETE"' + "`n" +
        'header = "Accept: application/json"' + "`n" +
        'user-agent = "framework-stata (fw_cloud.ps1)"' + "`n" +
        'output = "' + ($body -replace '\\', '/') + '"' + "`n" +
        'write-out = "%{http_code}"' + "`nsilent`nshow-error`nconnect-timeout = 20`nmax-time = 30`n"
    if ($env:FW_CLOUD_INSECURE) { $text += "insecure`n" }
    Utf8NoBom $cfg $text
    try {
        $rc = CurlWith $cfg $tok $out
        if ($rc -ne 0) { return $false }
        $status = (Get-Content (Join-Path $out 'status.txt') -Raw).Trim()
        return ($status -match '^2\d\d$' -or $status -eq '401')
    } catch {
        return $false
    } finally {
        foreach ($f in @($cfg, $body, (Join-Path $out 'status.txt'))) {
            if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
        }
    }
}

switch ($action) {
    'http' {
        $cfg = $args[1]; $kind = $args[2]; $root = $args[3]; $h = $args[4]; $out = $args[5]
        $tok = ''
        if ($kind -eq 'project') {
            $tok = ProjectToken $root
            if (-not $tok) { Utf8NoBom (Join-Path $out 'problem.txt') 'no-project-token'; exit 3 }
        } elseif ($kind -eq 'user') {
            $tok = (UserToken $h)[0]
            if (-not $tok) { Utf8NoBom (Join-Path $out 'problem.txt') 'no-user-token'; exit 3 }
        }
        exit (CurlWith $cfg $tok $out)
    }
    'poll' {
        $cfg = $args[1]; $h = $args[2]; $server = $args[3]; $out = $args[4]
        & curl.exe -K $cfg 1> (Join-Path $out 'status.txt') 2> (Join-Path $out 'curl.err')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        if ((Get-Content (Join-Path $out 'status.txt') -Raw).Trim() -ne '200') { exit 0 }
        $body = Join-Path $out 'poll.json'
        $tok = (Get-Content -LiteralPath $body -Raw | ConvertFrom-Json).token
        Remove-Item -LiteralPath $body -Force
        if (-not $tok) { Utf8NoBom (Join-Path $out 'problem.txt') 'no-token-in-response'; exit 4 }
        $rc = CurlWith (MeConfig $server $out) $tok $out
        if ($rc -ne 0) { exit $rc }
        if ((Get-Content (Join-Path $out 'status.txt') -Raw).Trim() -ne '200') {
            Utf8NoBom (Join-Path $out 'problem.txt') 'token-rejected'; exit 5
        }
        Utf8NoBom (Join-Path $out 'stored.txt') (StoreToken $h $tok)
        Utf8NoBom (Join-Path $out 'status.txt') '200'
        exit 0
    }
    'status' {
        $r = UserToken $args[1]
        if ($r[0]) { Write-Output $r[1] } else { Write-Output 'none' }
        exit 0
    }
    'check' {
        $h = $args[1]; $server = $args[2]; $out = $args[3]
        $tok = (UserToken $h)[0]
        if (-not $tok) { Utf8NoBom (Join-Path $out 'problem.txt') 'no-user-token'; exit 3 }
        exit (CurlWith (MeConfig $server $out) $tok $out)
    }
    'logout' {
        $h = $args[1]; $server = $args[2]; $out = $args[3]
        # Revoke each stored token that logout removes, then remove it.
        # FW_CLOUD_TOKEN is not removed, so it is not revoked.
        $toks = @()
        $t = [FwCred]::Read(':framework-cloud:' + $h + ':token')
        if ($t) { $toks += $t }
        $f = Join-Path (CfgDir) (TokName $h)
        if (Test-Path -LiteralPath $f) { $toks += (FirstLine $f) }
        if ($env:FW_TOKEN_FILE -and (Test-Path -LiteralPath $env:FW_TOKEN_FILE)) { $toks += (FirstLine $env:FW_TOKEN_FILE) }
        $toks = @($toks | Where-Object { $_ } | Select-Object -Unique)
        if ($toks.Count -gt 0) {
            $ok = $true
            foreach ($t in $toks) { if (-not (RevokeToken $t $server $out)) { $ok = $false } }
            if ($ok) { Write-Output 'revoked' } else { Write-Output 'not-revoked' }
        }
        $toks = $null; $t = $null
        $removed = ''
        if ([FwCred]::Delete(':framework-cloud:' + $h + ':token')) { $removed += ' keyring' }
        $f = Join-Path (CfgDir) (TokName $h)
        if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force; $removed += ' ' + $f }
        if ($env:FW_TOKEN_FILE -and (Test-Path -LiteralPath $env:FW_TOKEN_FILE)) {
            Remove-Item -LiteralPath $env:FW_TOKEN_FILE -Force; $removed += ' ' + $env:FW_TOKEN_FILE
        }
        $r = Join-Path (RCfgDir) (TokName $h)
        if (Test-Path -LiteralPath $r) { Write-Output ('r-file ' + $r) }
        Write-Output ('removed' + $removed)
        exit 0
    }
    default { Write-Error "fw_cloud.ps1: unknown action $action"; exit 2 }
}
