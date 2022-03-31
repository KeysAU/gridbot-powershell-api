

##
# URL & AUth Details:
##

$TodayString = Get-Date -Format yyyy-MM-dd

$global:uri = "https://paper-api.alpaca.markets"
$global:account_uri = "/v2/account"
$global:orders_uri = "/v2/orders"

$global:Key = "xxxx"
$global:Secret = "xxxxx"

##
# Sell Crypto
##

$global:auth_headers = @{
    "APCA-API-KEY-ID"     = $global:Key
    "APCA-API-SECRET-KEY" = $global:Secret
}

#grid bot settings

$Num_Buy_Grid_lines = 0..15
$Num_sell_Grid_lines = 0..15
$Grid_size = 20
$position_size = 0.005

$Check_orders_frequency = 2
$Closed_Order_Status = 'closed'

$buy_orders = @()
$sell_orders = @()
$closed_order_ids = @()

$first_buy_order_body = [ordered]@{    

    "symbol"        = "BTCUSD"
    "qty"           = 1
    "type"          = "market"
    "side"          = "buy"
    #"limit_price"   = [int]($Current_Coin_Price.Current_Coin_Price) + 10
    "time_in_force" = "gtc"

}                
$submit_buy_order_body = $first_buy_order_body | ConvertTo-Json

$first_buy_Order = Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_buy_order_body       
$first_Validate_Order = Invoke-RestMethod -Uri ($uri + $orders_uri + "/$($first_buy_Order.id)") -Method Get -Headers $global:auth_headers

foreach ($i in $Num_Buy_Grid_lines) {

    $buy_order_bodys = [ordered]@{    

        "symbol"        = "BTCUSD"
        "qty"           = $position_size
        "type"          = "limit"
        "side"          = "buy"
        "limit_price"   = ([math]::Round([int]$first_Validate_Order.filled_avg_price,1) - ($Grid_size * ($i + 1.0)))
        "time_in_force" = "gtc"
    }
    $submit_buy_order_body = $buy_order_bodys | ConvertTo-Json
    $buy_Orders += Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_buy_order_body
    #$buy_order_bodys.limit_price
}

foreach ($i in $Num_sell_Grid_lines) {

    $sell_order_bodys = [ordered]@{    

        "symbol"        = "BTCUSD"
        "qty"           = $position_size
        "type"          = "limit"
        "side"          = "sell"
        "limit_price"   = ([math]::Round([int]$first_Validate_Order.filled_avg_price,1) + ($Grid_size * ($i + 1.0)))
        "time_in_force" = "gtc"
    }
    $submit_sell_order_body = $sell_order_bodys | ConvertTo-Json
    $sell_Orders += Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_sell_order_body
    #$sell_order_bodys.limit_price
}


$Loop = $True
while ($Loop  = $True) {    
    
    Start-Sleep -Seconds 1

    foreach ($Buy_order in $buy_Orders) {

        Write-Host ("Checking buy order: $($Buy_Order.id)")

        try { $Buy_Validate_Order = Invoke-RestMethod -Uri ($uri + $orders_uri + "/$($Buy_order.id)") -Method Get -Headers $global:auth_headers }
        catch {
            Write-Host "Request Failed"
            continue
        }
       $Buy_Order_info = $Buy_Validate_Order

        if ($Buy_Order_info.status -eq "Filled") {

            Write-Host "Buy order executed at: $($Buy_Order_info.filled_avg_price)"

            $closed_order_ids += $Buy_Order_info.id
            $new_sell_price = ([math]::Round([int]$Buy_Order_info.filled_avg_price,1)) + [int]$Grid_size

            $new_sell_order = [ordered]@{    

                "symbol"        = "BTCUSD"
                "qty"           = $position_size
                "type"          = "limit"
                "side"          = "sell"
                "limit_price"   = [int]$new_sell_price 
                "time_in_force" = "gtc"
            }
            Write-Host "Creating new limit sell order at: $($new_sell_price)"
            $submit_new_sell_order_body = $new_sell_order | ConvertTo-Json
            $sell_orders += Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_new_sell_order_body
        }
    }

    Write-Host ("Checking for open sell orders")    

    foreach ($sell_order in $sell_orders) {
        
        Write-Host ("Checking sell order: $($sell_order.id)")
        try { $Sell_Validate_Order = Invoke-RestMethod -Uri ($uri + $orders_uri + "/$($sell_order.id)") -Method Get -Headers $global:auth_headers }
        catch {
            Write-Host "Request Failed"
            continue
        }
        $sell_order_info = $Sell_Validate_Order

        if ($sell_order_info.status -eq "Filled") {

            $closed_order_ids += $sell_order_info.id
            Write-Host "sell order executed at: $($sell_order_info.filled_avg_price)"
            $new_buy_price = ([math]::Round([int]$sell_order_info.filled_avg_price,1)) - [int]$Grid_size

            Write-Host "Creating new limit buy order at: $($new_buy_price)"
            $new_buy_order = [ordered]@{    

                "symbol"        = "BTCUSD"
                "qty"           = $position_size
                "type"          = "limit"
                "side"          = "buy"
                "limit_price"   = [int]$new_buy_price 
                "time_in_force" = "gtc"
            }
            
            $submit_new_buy_order_body = $new_buy_order | ConvertTo-Json
            $buy_orders += Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_new_buy_order_body
        }
    }

    Start-Sleep -Seconds 1

    foreach ($order_id in $closed_order_ids) {

        $buy_orders = foreach ($Buy_order in $buy_Orders) {
    
            $Buy_order | Where-Object { $_.id -ne $order_id } 
        }
    
        $sell_orders = foreach ($sell_order in $sell_orders) {
    
            $sell_order | Where-Object { $_.id -ne $order_id }
        }
    }
    
    If ([string]::IsNullOrEmpty($sell_orders)) {
        Write-Host "Stopping bot, nothing left to sell"
        break
    }
}




#$buy_Order | Add-Member -MemberType NoteProperty -Name "pers_static_ID" -Value $buy_or_sell_index.pers_static_ID -Force
#$buy_order | ConvertTo-Json | Out-File "C:\Play\ScriptBot\$($TodayString)\3-Buy-Sell\buy_$($buy_Order.id).json" -Force    

