# Gridbot-Powershell-API

Description:

    Run a gridbot using real-time market data using web api in powershell!

    1.) Automatically buys X amount at current market price.

    2.) Sets up a gride price - a high price, low price "grid" to trade within.

    3.) Buys low / Sell high.

    4.) When it makes a succesful trade, it automatically place another trade, based on your grid size.

    E.g: Buys at 4250, will place a sell limit order at $4300, assuming your grid size is 50.
    E.g: Sells at 4250, will place another buy limit order at $4200, assuming your grid size is 50.

    Runs until you tell it not to, or you loose $500.

PreReq:

    Setup an account on https://alpaca.markets/ and generate an API key on the paper trading.
    Enter in your key & secret on lines 69,70
    Adjust your grid bot settings under gridbot settings. 

Logs:

    Logs get output to C:\Tax-Grdibot
        Tax Logs: "C:\Tax-Grdibot\yyyy\yyyy-mm-dd-Tax.csv"
        Script console Logs: "C:\Tax-Grdibot\ScriptLogs\yyyy-mm-dd-log.txt"

Note:

    Setup for Australian Taxation.

Image:

![image](https://user-images.githubusercontent.com/38932932/162602329-d2970d0a-ca0b-4787-b1fa-22112cc3845d.png)
