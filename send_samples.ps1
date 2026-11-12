# Sends the sample leads to the workflow and prints each answer.
# The hot lead is sent twice on purpose: the second answer should be "duplicate".
# Run:  powershell -ExecutionPolicy Bypass -File send_samples.ps1
$url = "http://localhost:5678/webhook/lead-intake"

foreach ($name in "hot_lead", "warm_lead", "cold_lead", "hot_lead") {
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    $body = Get-Content "$PSScriptRoot\samples\$name.json" -Raw
    Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json; charset=utf-8" -Body $body |
        ConvertTo-Json -Depth 5
}
