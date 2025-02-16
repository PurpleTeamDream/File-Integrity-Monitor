# Prompt the user to enter the target folder path
$targetFolder = Read-Host "Please enter the target folder path"

# Store the target folder path in a variable
$files = Get-ChildItem -Path $targetFolder

Write-Host ""
Write-Host "What would you like to do?"
Write-Host "A) Collect new Baseline?"
Write-Host "B) Begin monitoring files with saved Baseline?"

$response = Read-Host -Prompt "Please enter 'A' or 'B'"
Write-Host "User entered $($response)"

Function Calculate-File-Hash($filepath) {
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
    return $filehash
}

Function Erase-Baseline-If-Already-Exists() {
    $baselinePath = Join-Path -Path $targetFolder -ChildPath "baseline.txt"
    $baselineExists = Test-Path -Path $baselinePath
    if ($baselineExists) {
        # Delete the thing 💣🧨💥
        Remove-Item -Path $baselinePath
    }
}

if ($response -eq "A".ToUpper()) {
    # Delete Baseline.txt if it exists
    Erase-Baseline-If-Already-Exists

    # Calculate Hash from the target files and store in the baseline.txt file
    Write-Host "Calculate Hashes, make new baseline.txt" -ForegroundColor Magenta

    # For each file, calculate the hash, and write to baseline.txt
    foreach ($f in $files) {
        $hash = Calculate-File-Hash $f.FullName
        "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath (Join-Path -Path $targetFolder -ChildPath "baseline.txt") -Append
    }

} elseif ($response -eq "B".ToUpper()) {

    $fileHashDictionary = @{}

    # Load file hash from baseline.txt and store them in a dictionary
    $filePathsandHashes = Get-Content -Path (Join-Path -Path $targetFolder -ChildPath "baseline.txt")

    foreach ($f in $filePathsandHashes) {
        $fileHashDictionary.Add($f.Split("|")[0], $f.Split("|")[1])
    }

    # Begin (continuously) monitoring files with saved baseline
    while ($true) {
        Start-Sleep -Seconds 1
        $files = Get-ChildItem -Path $targetFolder | Where-Object { $_.Name -ne "baseline.txt" }

        # For each file, calculate the hash, and write to baseline.txt
        foreach ($f in $files) {
            $hash = Calculate-File-Hash $f.FullName

            # Notify if a new file has been created
            if ($fileHashDictionary[$hash.Path] -eq $null) {
                # A new file has been created!
                Write-Host "$($hash.Path) has been created!" -ForegroundColor Green
            } else {
                # Notify if a new file has been changed
                if ($fileHashDictionary[$hash.Path] -eq $hash.Hash) {
                    # The file has not changed
                } else {
                    # File has been compromised!! Notify the user!
                    Write-Host "$($hash.Path) has changed!!!" -ForegroundColor Yellow
                }
            }
        }

        foreach ($key in $fileHashDictionary.Keys) {
            $baselineFileStillExists = Test-Path -Path $key
            if (-Not $baselineFileStillExists) {
                # One of the baseline files must have been deleted! Notify user
                Write-Host "$($key) has been deleted!" -ForegroundColor Red
            }
        }
    }
}
