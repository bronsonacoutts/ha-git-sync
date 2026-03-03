$OWNER = $env:GH_OWNER
if (-not $OWNER) {
    $originUrl = git remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and $originUrl -match '[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(?:\.git)?$') {
        $OWNER = $Matches['owner']
    }
}
if (-not $OWNER) {
    # Fallback to upstream owner if environment and git remote are unavailable.
    $OWNER = "bronsonacoutts"
}
$REPO  = "ha-git-sync"
$GH_TOKEN = $env:GH_TOKEN

if (-not $GH_TOKEN) { throw "Set GH_TOKEN env var first." }
$H1 = "Authorization: Bearer $GH_TOKEN"
$H2 = "Accept: application/vnd.github+json"
$H3 = "X-GitHub-Api-Version: 2022-11-28"
