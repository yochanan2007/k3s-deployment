# GitOps Setup Script for K3s
# This script initializes the local git repository and pushes to GitHub

Write-Host "=== K3s GitOps Setup Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the correct directory
$currentDir = Get-Location
Write-Host "Current directory: $currentDir" -ForegroundColor Yellow

# Check if git is installed
try {
    $gitVersion = git --version
    Write-Host "Git found: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Git is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if .git directory exists
if (Test-Path ".git") {
    Write-Host "WARNING: Git repository already initialized" -ForegroundColor Yellow
    $response = Read-Host "Do you want to continue? This will keep existing git config (y/n)"
    if ($response -ne "y") {
        Write-Host "Setup cancelled" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "Initializing git repository..." -ForegroundColor Cyan
    git init
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Git repository initialized successfully" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to initialize git repository" -ForegroundColor Red
        exit 1
    }
}

# Configure git user
Write-Host ""
Write-Host "Configuring git user..." -ForegroundColor Cyan
git config user.email "yochanan2007@gmail.com"
git config user.name "yochanan2007"
Write-Host "Git user configured" -ForegroundColor Green

# Check for remote
$remotes = git remote -v
if ($remotes -match "origin") {
    Write-Host "Remote 'origin' already exists:" -ForegroundColor Yellow
    Write-Host $remotes
} else {
    Write-Host "Adding GitHub remote..." -ForegroundColor Cyan
    git remote add origin https://github.com/yochanan2007/k3s.git
    Write-Host "Remote added successfully" -ForegroundColor Green
}

# Stage all files
Write-Host ""
Write-Host "Staging all files..." -ForegroundColor Cyan
git add .
$stagedFiles = git diff --cached --name-only
$fileCount = ($stagedFiles | Measure-Object).Count
Write-Host "Staged $fileCount files" -ForegroundColor Green

# Show what will be committed
Write-Host ""
Write-Host "Files to be committed:" -ForegroundColor Yellow
git diff --cached --name-status

# Confirm commit
Write-Host ""
$response = Read-Host "Do you want to commit these files? (y/n)"
if ($response -ne "y") {
    Write-Host "Commit cancelled. Files remain staged." -ForegroundColor Yellow
    exit 0
}

# Create commit
Write-Host ""
Write-Host "Creating commit..." -ForegroundColor Cyan
$commitMessage = @"
Initial commit: K3s GitOps deployment manifests

- Add AdGuard Home deployment (6 YAML files)
- Add Traefik configuration with Let's Encrypt (4 YAML files)
- Add cert-manager configuration (3 YAML files)
- Add Fleet GitOps configuration
- Add comprehensive documentation (README, DEPLOYMENT_SUMMARY, VERIFICATION_REPORT)
- Add .gitignore for local files

All manifests verified against running cluster at 10.0.0.210
"@

git commit -m $commitMessage
if ($LASTEXITCODE -eq 0) {
    Write-Host "Commit created successfully" -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to create commit" -ForegroundColor Red
    exit 1
}

# Push to GitHub
Write-Host ""
Write-Host "Ready to push to GitHub: https://github.com/yochanan2007/k3s" -ForegroundColor Yellow
Write-Host ""
Write-Host "NOTE: You may be prompted for GitHub credentials." -ForegroundColor Yellow
Write-Host "      If using 2FA, you'll need a Personal Access Token instead of password." -ForegroundColor Yellow
Write-Host ""
$response = Read-Host "Push to GitHub now? (y/n)"
if ($response -ne "y") {
    Write-Host "Push cancelled. You can push later with: git push -u origin main" -ForegroundColor Yellow
    exit 0
}

# Check if main branch exists on remote
Write-Host ""
Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push -u origin main
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully pushed to GitHub!" -ForegroundColor Green
} else {
    Write-Host "Push failed. Trying with --force (repository might have existing content)..." -ForegroundColor Yellow
    Write-Host "WARNING: This will overwrite remote repository content!" -ForegroundColor Red
    $response = Read-Host "Continue with force push? (y/n)"
    if ($response -eq "y") {
        git push -u origin main --force
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully pushed to GitHub with --force!" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Force push failed. Please check your GitHub credentials and repository access." -ForegroundColor Red
            Write-Host ""
            Write-Host "Troubleshooting:" -ForegroundColor Yellow
            Write-Host "1. Verify repository exists: https://github.com/yochanan2007/k3s" -ForegroundColor Yellow
            Write-Host "2. Check if you need a Personal Access Token (Settings > Developer settings > Personal access tokens)" -ForegroundColor Yellow
            Write-Host "3. Ensure you have write access to the repository" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "Force push cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Success summary
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Verify repository at: https://github.com/yochanan2007/k3s" -ForegroundColor White
Write-Host "2. Apply Fleet GitRepo configuration:" -ForegroundColor White
Write-Host "   kubectl apply -f fleet-gitrepo.yaml" -ForegroundColor Yellow
Write-Host "3. Monitor Fleet sync:" -ForegroundColor White
Write-Host "   kubectl get gitrepo -n fleet-local" -ForegroundColor Yellow
Write-Host ""
Write-Host "For detailed instructions, see GITOPS_SETUP.md" -ForegroundColor Cyan
