# Simple Aliases Configuration
# This file contains basic command aliases

# File system aliases
Set-Alias -Name vs -Value 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\devenv.exe'
Set-Alias -Name v -Value nvim
Set-Alias -Name g -Value git
Set-Alias -Name gui -Value gitui
Set-Alias -Name vim -Value "$env:LOCALAPPDATA\Programs\Git\usr\bin\vim.exe"
Set-Alias -Name dk -Value docker
Set-Alias -Name dkc -Value 'docker compose'

# Quick exit alias (vim-style)
Set-Alias -Name :q -Value exit
