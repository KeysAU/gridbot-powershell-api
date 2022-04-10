

##
# Path & Logging
##

# Setup Tax Folder Stucture
$ScriptPath = "C:\Tax-Grdibot"
$yyyy = Get-Date -Format yyyy
$yyyy_MM_dd = Get-Date -Format yyyy-MM-dd

if (!(Test-Path "$ScriptPath\$yyyy")) {

    mkdir -Path "$ScriptPath\$yyyy"
}

if (!(Test-Path "$ScriptPath\ScriptLogs")) {

    mkdir -Path "$ScriptPath\ScriptLogs"
}

function Write-Log {
    Param(
        $Message,
        $Path = "$ScriptPath\scriptlogs\$yyyy_mm_dd-log.txt"
    )

    function TS { Get-Date -Format 'yyyy-MM-dd hh:mm:ss' }
    "$(TS): $Message" | Tee-Object -FilePath $Path -Append | Write-Verbose
    Write-Host $Message
}

function Get-ExchangeRate {

    [CmdletBinding()]
    param (
        [Parameter(
            ValueFromPipelineByPropertyName)]
        $filled_avg_price
    )

    $yyyy = Get-Date -Format yyyy
    $yyyy_MM_dd = Get-Date -Format yyyy-MM-dd

    if (!(Test-Path "$ScriptPath\$yyyy")) {
        mkdir -Path "$ScriptPath\$yyyy"      
    }

    try { Invoke-RestMethod -Uri ($Global:Exchg_rate_uri + $filled_avg_price) }
    catch {
        "Exchange Rate Request Failed"
        continue
    } 
}

Write-Log '---Start-Log---'

##
# URL & AUth Details:
##

$TodayString = Get-Date -Format yyyy-MM-dd

$global:uri = "https://paper-api.alpaca.markets"
$global:account_uri = "/v2/account"
$global:orders_uri = "/v2/orders"
$global:positions_uri = "/v2/positions"

$global:Key = "xxxxx"
$global:Secret = "xxxxx"

$global:auth_headers = @{
    "APCA-API-KEY-ID"     = $global:Key
    "APCA-API-SECRET-KEY" = $global:Secret
}

##
# Tax Information
##

$From_Currency = "USD"
$To_Currency = "AUD"
$Global:Exchg_rate_uri = "https://api.exchangerate.host/convert?from=$($From_Currency)&to=$($To_Currency)&amount="


##
# Grid bot settings
##

$TestArray = @() #Testing Array

$Num_Buy_Grid_lines = 0..10
$Num_sell_Grid_lines = 0..10
$Grid_size = 50
$position_size = 0.001
$trading_symbol = "BTCUSD"

$buy_orders = @()
$sell_orders = @()
$closed_order_ids = @()

$first_buy_order_body = [ordered]@{    

    "symbol"        = $trading_symbol
    "qty"           = 0.011
    "type"          = "market"
    "side"          = "buy"    
    "time_in_force" = "gtc"

}                
$submit_buy_order_body = $first_buy_order_body | ConvertTo-Json

##
# Submit First Buy Order
##
$first_buy_Order = Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_buy_order_body       
$first_Validate_Order = Invoke-RestMethod -Uri ($uri + $orders_uri + "/$($first_buy_Order.id)") -Method Get -Headers $global:auth_headers

Write-Log "Logging First Buy Tax Information."

##
# Tax Informaion: 
##

$tax_AUD_USD_exg_rate_info = $first_Validate_Order | Get-ExchangeRate

$first_Validate_Order | Add-Member -MemberType NoteProperty -Name "tax_date_time_transaction_utc" -Value $first_Validate_Order.filled_at
$first_Validate_Order | Add-Member -MemberType NoteProperty -Name "tax_AUD_purchase_price" -Value $tax_AUD_USD_exg_rate_info.result
$first_Validate_Order | Add-Member -MemberType NoteProperty -Name "tax_USD_purchase_price" -Value $first_Validate_Order.filled_avg_price
$first_Validate_Order | Add-Member -MemberType NoteProperty -Name "tax_AUD_Conversion_USD_rate" -Value $tax_AUD_USD_exg_rate_info.info.rate
$first_Validate_Order | Add-Member -MemberType NoteProperty -Name "tax_transaction_reason_1" -Value "Crypto bot trading. Purpose of frequently buying and selling crypto currency for profit."
$first_Validate_Order | Add-Member -MemberType NoteProperty -Name "tax_transaction_reason_2" -Value "Transaction was to Alpaca Securities LLC."    

$Export_Tax_info = [PSCustomObject]@{            

    Tax_buy_or_sell               = "Buy"
    tax_date_time_transaction_utc = $first_Validate_Order.tax_date_time_transaction_utc
    tax_symbol                    = $first_Validate_Order.symbol
    tax_asset_class               = $first_Validate_Order.asset_class
    tax_qty                       = $first_Validate_Order.qty
    tax_order_type                = $first_Validate_Order.order_type
    tax_AUD_purchase_price        = $first_Validate_Order.tax_AUD_purchase_price
    tax_USD_purchase_price        = $first_Validate_Order.tax_USD_purchase_price
    tax_AUD_Conversion_USD_rate   = $first_Validate_Order.tax_AUD_Conversion_USD_rate
    tax_transaction_reason_1      = $first_Validate_Order.tax_transaction_reason_1
    tax_transaction_reason_2      = $first_Validate_Order.tax_transaction_reason_2
    tax_id                        = $first_Validate_Order.id
    AuditData                     = $first_Validate_Order | ConvertTo-Json -Depth 100 -Compress
}

$Export_Tax_info | Export-csv "$ScriptPath\$yyyy\$yyyy_MM_dd-Tax.csv" -Append -NoTypeInformation

foreach ($i in $Num_Buy_Grid_lines) {

    $buy_order_bodys = [ordered]@{    

        "symbol"        = $trading_symbol
        "qty"           = $position_size
        "type"          = "limit"
        "side"          = "buy"
        "limit_price"   = ([math]::Round([int]$first_Validate_Order.filled_avg_price, 1)) - ($Grid_size * ($i + 1.0))
        "time_in_force" = "gtc"
    }
    $submit_buy_order_body = $buy_order_bodys | ConvertTo-Json
    $buy_Orders += Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_buy_order_body
    $TestArray += $buy_order_bodys.limit_price
}

foreach ($i in $Num_sell_Grid_lines) {

    $sell_order_bodys = [ordered]@{    

        "symbol"        = $trading_symbol
        "qty"           = $position_size
        "type"          = "limit"
        "side"          = "sell"
        "limit_price"   = ([math]::Round([int]$first_Validate_Order.filled_avg_price, 1)) + ($Grid_size * ($i + 1.0))
        "time_in_force" = "gtc"
    }
    $submit_sell_order_body = $sell_order_bodys | ConvertTo-Json
    $sell_Orders += Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_sell_order_body
    $TestArray += $sell_order_bodys.limit_price
}

$Loop = $True
while ($Loop = $True) {    
    
    Start-Sleep -Seconds 1

    Write-Host "Checking for open buy orders:" 
    foreach ($Buy_order in $buy_Orders) {

        Write-Host ("Checking buy order: $($Buy_Order.id) | Limit Price: $($Buy_order.limit_price)")

        try { $Buy_Validate_Order = Invoke-RestMethod -Uri ($uri + $orders_uri + "/$($Buy_order.id)") -Method Get -Headers $global:auth_headers }
        catch {
            Write-Log "Buy Validate Ordr Request Failed"
            continue
        }

        $Buy_Order_info = $Buy_Validate_Order

        if ($Buy_Order_info.status -eq "Filled") {

            Write-Log "Buy order executed at: $($Buy_Order_info.filled_avg_price)"
            Write-Log "Logging Buy Tax Information."

            ##
            # Tax Informaion: 
            ##

            $tax_AUD_USD_exg_rate_info = $Buy_Order_info | Get-ExchangeRate

            $Buy_order_info | Add-Member -MemberType NoteProperty -Name "tax_date_time_transaction_utc" -Value $Buy_Order_info.filled_at
            $Buy_order_info | Add-Member -MemberType NoteProperty -Name "tax_AUD_purchase_price" -Value $tax_AUD_USD_exg_rate_info.result
            $Buy_order_info | Add-Member -MemberType NoteProperty -Name "tax_USD_purchase_price" -Value $Buy_Order_info.filled_avg_price
            $Buy_order_info | Add-Member -MemberType NoteProperty -Name "tax_AUD_Conversion_USD_rate" -Value $tax_AUD_USD_exg_rate_info.info.rate
            $Buy_order_info | Add-Member -MemberType NoteProperty -Name "tax_transaction_reason_1" -Value "Crypto bot trading. Purpose of frequently buying and selling crypto currency for profit."
            $Buy_order_info | Add-Member -MemberType NoteProperty -Name "tax_transaction_reason_2" -Value "Transaction was to Alpaca Securities LLC."    
            
            $Export_Tax_info = [PSCustomObject]@{            

                Buy_or_Sell               = "Buy"
                tax_date_time_transaction_utc = $Buy_Order_info.tax_date_time_transaction_utc
                tax_symbol                    = $Buy_Order_info.symbol
                tax_asset_class               = $Buy_Order_info.asset_class
                tax_qty                       = $Buy_Order_info.qty
                tax_order_type                = $Buy_Order_info.order_type
                tax_AUD_purchase_price        = $Buy_Order_info.tax_aud_filled_avg_price
                tax_USD_purchase_price        = $Buy_Order_info.tax_aud_filled_avg_price
                tax_AUD_Conversion_USD_rate   = $Buy_Order_info.tax_AUD_Conversion_USD_rate
                tax_transaction_reason_1      = $Buy_Order_info.tax_transaction_reason_1
                tax_transaction_reason_2      = $Buy_Order_info.tax_transaction_reason_2
                tax_id                        = $Buy_Order_info.id
                AuditData                     = $Buy_Order_info | ConvertTo-Json -Depth 100 -Compress
            }

            $Export_Tax_info | Export-csv "$ScriptPath\$yyyy\$yyyy_MM_dd-Tax.csv" -Append -NoTypeInformation

            $closed_order_ids += $Buy_Order_info.id
            $new_sell_price = ([math]::Round([int]$Buy_Order_info.filled_avg_price)) + ([int]$Grid_size)

            $new_sell_order = [ordered]@{    

                "symbol"        = $trading_symbol
                "qty"           = $position_size
                "type"          = "limit"
                "side"          = "sell"
                "limit_price"   = [int]$new_sell_price 
                "time_in_force" = "gtc"
            }
            Write-Log "Creating new limit sell order at: $($new_sell_price)"
            Write-Log "Previous bought price was $($buy_order_info.filled_avg_price)"

            $submit_new_sell_order_body = $new_sell_order | ConvertTo-Json
            $sell_orders += Invoke-RestMethod -Uri ($global:uri + $global:orders_uri) -Method Post -Headers $global:auth_headers -Body $submit_new_sell_order_body
        }
    }

    Write-Host "=================="

    Write-Host "Checking for open sell orders:" 

    foreach ($sell_order in $sell_orders) {
        
        Write-Host ("Checking sell order: $($sell_order.id) | Limit Price: $($sell_order.limit_price)") 
        try { $Sell_Validate_Order = Invoke-RestMethod -Uri ($uri + $orders_uri + "/$($sell_order.id)") -Method Get -Headers $global:auth_headers }
        catch {
            Write-Log "Sell_Validate_Order Request Failed"
            continue
        }
        $sell_order_info = $Sell_Validate_Order

        if ($sell_order_info.status -eq "Filled") {

            Write-Log "Logging Sell Tax Information."

            ##
            # Tax Informaion: 
            ##

            $tax_AUD_USD_exg_rate_info = $sell_order_info | Get-ExchangeRate

            $sell_order_info | Add-Member -MemberType NoteProperty -Name "tax_date_time_transaction_utc" -Value $sell_order_info.filled_at
            $sell_order_info | Add-Member -MemberType NoteProperty -Name "tax_AUD_purchase_price" -Value $tax_AUD_USD_exg_rate_info.result
            $sell_order_info | Add-Member -MemberType NoteProperty -Name "tax_USD_purchase_price" -Value $sell_order_info.filled_avg_price
            $sell_order_info | Add-Member -MemberType NoteProperty -Name "tax_AUD_Conversion_USD_rate" -Value $tax_AUD_USD_exg_rate_info.info.rate
            $sell_order_info | Add-Member -MemberType NoteProperty -Name "tax_transaction_reason_1" -Value "Crypto bot trading. Purpose of frequently buying and selling crypto currency for profit."
            $sell_order_info | Add-Member -MemberType NoteProperty -Name "tax_transaction_reason_2" -Value "Transaction was to Alpaca Securities LLC."    
            
            $Export_Tax_info = [PSCustomObject]@{            

                Buy_or_Sell               = "Buy"
                tax_date_time_transaction_utc = $sell_order_info.tax_date_time_transaction_utc
                tax_symbol                    = $sell_order_info.symbol
                tax_asset_class               = $sell_order_info.asset_class
                tax_qty                       = $sell_order_info.qty
                tax_order_type                = $sell_order_info.order_type
                tax_AUD_purchase_price        = $sell_order_info.tax_aud_filled_avg_price
                tax_USD_purchase_price        = $sell_order_info.tax_aud_filled_avg_price
                tax_AUD_Conversion_USD_rate   = $sell_order_info.tax_AUD_Conversion_USD_rate
                tax_transaction_reason_1      = $sell_order_info.tax_transaction_reason_1
                tax_transaction_reason_2      = $sell_order_info.tax_transaction_reason_2
                tax_id                        = $sell_order_info.id
                AuditData                     = $sell_order_info | ConvertTo-Json -Depth 100 -Compress
            }

            $Export_Tax_info | Export-csv "$ScriptPath\$yyyy\$yyyy_MM_dd-Tax.csv" -Append -NoTypeInformation

            $closed_order_ids += $sell_order_info.id
            Write-Log "sell order executed at: $($sell_order_info.filled_avg_price)"
            $new_buy_price = ([math]::Round([int]$sell_order_info.filled_avg_price)) - ([int]$Grid_size)

            Write-Log "Creating new limit buy order at: $($new_buy_price)"
            Write-Log "Previous sold price was $($sell_order_info.filled_avg_price)"
            $new_buy_order = [ordered]@{    

                "symbol"        = $trading_symbol
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
    
    $unrealized_pl = Invoke-RestMethod -Uri ($uri + $positions_uri + "/$($trading_symbol)") -Method Get -Headers $global:auth_headers
    $Stop_loop = [math]::Round([int]$unrealized_pl.unrealized_pl)

    if ($Stop_loop -gt +500) {

        Write-Log "Profit exceeded $ 500. Stopping Bot"

        $Loop = $false
        break
    }

    if (($Stop_loop -lt -500)) {

        Write-Log "Loss exceeded $ 500. Stopping Bot"

        $Loop = $false
        break
    }
    Write-Host "No Exit Profit: $($Stop_loop)"
    Write-Host "=================="
}



