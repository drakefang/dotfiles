
function proxy {
    $url ="http://127.0.0.1:33210"
    Set-Item Env:https_proxy $url
    Set-Item Env:http_proxy $url
}

function unproxy {
    Remove-Item Env:http_proxy
    Remove-Item Env:https_proxy
}

New-Alias -Name spp -Value proxy
New-Alias -Name upp -Value unproxy
New-Alias -Name open -Value explorer

$env:RUSTUP_UPDATE_ROOT="https://mirrors.aliyun.com/rustup/rustup"
$env:RUSTUP_DIST_SERVER="https://mirrors.aliyun.com/rustup"