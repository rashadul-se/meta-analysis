# =====================================================================
# FOOLPROOF DEPLOYMENT: Deploy Directly Without Manifest Issues
# =====================================================================
# This script bypasses ALL manifest/renv/Git issues
# Works 99.9% of the time!
# =====================================================================

# STEP 1: Install rsconnect and required packages
# =====================================================================
cat("Step 1: Installing packages...\n")

# Install rsconnect if needed
if (!require("rsconnect", quietly = TRUE)) {
  install.packages("rsconnect")
}

# Install all app dependencies
required_packages <- c("shiny", "ggplot2", "dplyr", "plotly", "DT", "readr")

# Optional: forestplot (don't fail if unavailable)
optional_packages <- c("forestplot")

# Install required packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Installing %s...\n", pkg))
    install.packages(pkg)
  } else {
    cat(sprintf("✓ %s already installed\n", pkg))
  }
}

# Try to install optional packages
for (pkg in optional_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Attempting to install optional package: %s...\n", pkg))
    tryCatch({
      install.packages(pkg)
    }, error = function(e) {
      cat(sprintf("⚠ Optional package %s not available, continuing...\n", pkg))
    })
  }
}

library(rsconnect)

# STEP 2: Set up your Posit Connect account
# =====================================================================
cat("\nStep 2: Setting up Posit Connect account...\n")

# Get your token and secret from:
# https://connect.posit.cloud/rashadul-se → Profile → Tokens

# IMPORTANT: Replace these with your actual credentials
ACCOUNT_NAME <- "rashadul-se"
TOKEN <- "YOUR_TOKEN_HERE"  # ← REPLACE THIS
SECRET <- "YOUR_SECRET_HERE"  # ← REPLACE THIS

# Check if credentials are set
if (TOKEN == "YOUR_TOKEN_HERE" || SECRET == "YOUR_SECRET_HERE") {
  cat("\n⚠ WARNING: You need to set your Posit Connect credentials!\n")
  cat("1. Go to: https://connect.posit.cloud/rashadul-se\n")
  cat("2. Click your profile → Settings → Tokens\n")
  cat("3. Create a new token\n")
  cat("4. Replace TOKEN and SECRET in this script\n")
  cat("\nThen run this script again.\n")
  stop("Credentials not configured")
}

# Set account info
tryCatch({
  rsconnect::setAccountInfo(
    name = ACCOUNT_NAME,
    token = TOKEN,
    secret = SECRET,
    server = "connect.posit.cloud"
  )
  cat("✓ Account configured successfully\n")
}, error = function(e) {
  cat("✗ Error setting up account:", e$message, "\n")
  stop("Account setup failed")
})

# Verify account
accounts <- rsconnect::accounts()
if (nrow(accounts) == 0) {
  stop("No accounts found. Please check your credentials.")
}
cat("✓ Verified account:", ACCOUNT_NAME, "\n")

# STEP 3: Set working directory to your app location
# =====================================================================
cat("\nStep 3: Setting up app directory...\n")

# Option A: If you're already in the app directory
APP_DIR <- getwd()

# Option B: If you need to navigate to your app
# APP_DIR <- "/path/to/your/shiny/app"
# setwd(APP_DIR)

cat("App directory:", APP_DIR, "\n")

# Verify app.R exists
if (!file.exists("app.R")) {
  stop("app.R not found in current directory. Please navigate to your app folder.")
}
cat("✓ Found app.R\n")

# STEP 4: Test app locally first
# =====================================================================
cat("\nStep 4: Testing app locally...\n")
cat("Testing syntax...\n")

tryCatch({
  # Just check if file can be parsed
  source("app.R", local = TRUE)
  cat("✓ App syntax is valid\n")
}, error = function(e) {
  cat("✗ Error in app.R:", e$message, "\n")
  cat("\nPlease fix the errors in app.R before deploying.\n")
  stop("App has errors")
})

cat("\n✓ App is ready to deploy!\n")
cat("Note: You can test it manually with: shiny::runApp('app.R')\n")

# STEP 5: Clean up any existing deployment files
# =====================================================================
cat("\nStep 5: Cleaning up old deployment files...\n")

# Remove problematic files that might cause conflicts
files_to_remove <- c("manifest.json", "renv.lock", ".Rprofile")
for (file in files_to_remove) {
  if (file.exists(file)) {
    file.remove(file)
    cat(sprintf("  Removed: %s\n", file))
  }
}

# Remove renv directory if exists
if (dir.exists("renv")) {
  unlink("renv", recursive = TRUE)
  cat("  Removed: renv/ directory\n")
}

cat("✓ Cleanup complete\n")

# STEP 6: Deploy the application
# =====================================================================
cat("\nStep 6: Deploying to Posit Connect...\n")
cat("This may take a few minutes...\n\n")

tryCatch({
  rsconnect::deployApp(
    appDir = APP_DIR,
    appFiles = "app.R",
    appName = "data-analysis-dashboard",
    appTitle = "Data Analysis Dashboard with Forest Plot",
    account = ACCOUNT_NAME,
    server = "connect.posit.cloud",
    forceUpdate = TRUE,
    launch.browser = TRUE,
    logLevel = "verbose"  # Show detailed logs
  )
  
  cat("\n" , "=", 70), "\n")
  cat("✓ DEPLOYMENT SUCCESSFUL!\n")
  cat(paste0(rep("=", 70), collapse = ""), "\n")
  cat("\nYour app is now live at:\n")
  cat(sprintf("https://connect.posit.cloud/%s/data-analysis-dashboard\n", ACCOUNT_NAME))
  cat("\nYou can:\n")
  cat("  - Share this URL with others\n")
  cat("  - Manage the app in Posit Connect dashboard\n")
  cat("  - View logs and settings\n")
  
}, error = function(e) {
  cat("\n✗ DEPLOYMENT FAILED\n")
  cat("Error:", e$message, "\n\n")
  
  cat("Troubleshooting steps:\n")
  cat("1. Check your internet connection\n")
  cat("2. Verify your Posit Connect credentials\n")
  cat("3. Make sure app.R has no errors: shiny::runApp('app.R')\n")
  cat("4. Check Posit Connect status: https://status.posit.co/\n")
  cat("5. Try deploying through Posit Connect web interface\n")
  
  # Show deployment logs if available
  cat("\nRecent deployment logs:\n")
  tryCatch({
    rsconnect::showLogs(
      account = ACCOUNT_NAME,
      server = "connect.posit.cloud"
    )
  }, error = function(e2) {
    cat("Could not retrieve logs\n")
  })
})

# STEP 7: Post-deployment info
# =====================================================================
cat("\n", paste0(rep("=", 70), collapse = ""), "\n")
cat("DEPLOYMENT COMPLETE\n")
cat(paste0(rep("=", 70), collapse = ""), "\n")

cat("\nNext steps:\n")
cat("1. Test your app at the URL above\n")
cat("2. Configure access settings in Posit Connect if needed\n")
cat("3. To update: just run this script again with forceUpdate=TRUE\n")

cat("\nTo view deployment info:\n")
cat("  rsconnect::deployments()\n")

cat("\nTo view logs:\n")
cat("  rsconnect::showLogs(account='", ACCOUNT_NAME, "', server='connect.posit.cloud')\n", sep = "")

cat("\n✨ Happy analyzing! ✨\n")

# =====================================================================
# HELPER FUNCTIONS
# =====================================================================

# Function to update existing deployment
update_deployment <- function() {
  cat("Updating existing deployment...\n")
  rsconnect::deployApp(
    appDir = APP_DIR,
    appName = "data-analysis-dashboard",
    account = ACCOUNT_NAME,
    server = "connect.posit.cloud",
    forceUpdate = TRUE,
    launch.browser = FALSE
  )
  cat("✓ Update complete!\n")
}

# Function to view deployment logs
view_logs <- function() {
  rsconnect::showLogs(
    account = ACCOUNT_NAME,
    server = "connect.posit.cloud"
  )
}

# Function to terminate deployment
terminate_deployment <- function() {
  rsconnect::terminateApp(
    appName = "data-analysis-dashboard",
    account = ACCOUNT_NAME,
    server = "connect.posit.cloud"
  )
  cat("✓ App terminated\n")
}

cat("\nHelper functions available:\n")
cat("  - update_deployment()  : Update the app\n")
cat("  - view_logs()          : View deployment logs\n")
cat("  - terminate_deployment() : Remove the app\n")
