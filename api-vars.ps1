$OWNER = "bronsonacoutts"
$REPO  = "ha-git-sync"
$GH_TOKEN = $env:GH_TOKEN

if (-not $GH_TOKEN) { throw "Set GH_TOKEN env var first." }
$H1 = "Authorization: Bearer $GH_TOKEN"
$H2 = "Accept: application/vnd.github+json"
$H3 = "X-GitHub-Api-Version: 2022-11-28"
