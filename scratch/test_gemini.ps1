$json = '{"contents":[{"parts":[{"text":"Hello"}]}]}'
$key = 'AQ.Ab8RN6J0ChBCTMqgrLKqih4PHHGLjbxLQdCt2OAh2NA84i7KhQ'
$headers = @{ 'x-goog-api-key' = $key; 'Content-Type' = 'application/json' }

foreach ($model in @('gemini-2.5-flash', 'gemini-2.0-flash-lite', 'gemini-2.5-flash-lite', 'gemini-flash-latest', 'gemini-3.6-flash')) {
    Write-Host "--- TESTING $model ---"
    try {
        $res = Invoke-RestMethod -Uri "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent" -Method Post -Headers $headers -Body $json
        Write-Host "SUCCESS for $model!"
        $res.candidates[0].content.parts[0].text
        break
    } catch {
        Write-Host "ERROR for ${model}:"
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $reader.ReadToEnd()
    }
}
