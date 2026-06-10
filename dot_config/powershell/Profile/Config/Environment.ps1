# Environment Configuration
# This file contains environment variables and path management

# Add any custom paths here if needed
# $env:PATH += ";C:\Your\Custom\Path"

# Set default editor if not already set
if (-not $env:EDITOR) {
    $env:EDITOR = 'nvim'
}

if (-not $env:VISUAL) {
    $env:VISUAL = 'code'
}
