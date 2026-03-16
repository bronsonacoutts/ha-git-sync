$originUrl = git remote get-url origin 2>$null

$OWNER = $env:GH_OWNER
if (-not $OWNER) {
    if ($LASTEXITCODE -eq 0 -and $originUrl -match '[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(?:\.git)?$') {
        $OWNER = $Matches['owner']
    }
}
if (-not $OWNER) {
    throw "Could not determine repository owner. Set GH_OWNER env var or configure a git remote."
}
$REPO = $env:GH_REPO
if (-not $REPO) {
    if ($originUrl -and $originUrl -match '[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(?:\.git)?$') {
        $REPO = $Matches['repo']
    }
}
if (-not $REPO) {
    $REPO = "ha-git-sync"
}
$GH_TOKEN = $env:GH_TOKEN

if (-not $GH_TOKEN) { throw "Set GH_TOKEN env var first." }
$AuthHeader = "Authorization: Bearer $GH_TOKEN"
$AcceptHeader = "Accept: application/vnd.github+json"
$ApiVersionHeader = "X-GitHub-Api-Version: 2022-11-28"
