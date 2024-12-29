
-- Helper function for debug logging
local function debugPrint(message)
    if config.debug then
        print("[^2DEBUG^0] " .. message)
    end
end

-- Ensure the resource name is correct
if (GetCurrentResourceName() ~= "money") then
    debugPrint("Please make sure the resource name is ^3money^0 or else exports won't work.")
end

local accounts = {}

-- Function to add money
function addMoney(id, amount)
    debugPrint(("addMoney called with id: %s, amount: %d"):format(id, amount))
    if accounts[id] then
        debugPrint(("Previous balance: %d"):format(accounts[id].amount))
        accounts[id].amount = accounts[id].amount + amount
        debugPrint(("New balance: %d"):format(accounts[id].amount))
        TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
    else
        debugPrint("Account not found for id: " .. id)
    end
end

-- Function to deduct money
function deductMoney(id, amount)
    debugPrint(("deductMoney called with id: %s, amount: %d"):format(id, amount))
    if accounts[id] then
        if accounts[id].amount >= amount then
            debugPrint(("Previous balance: %d"):format(accounts[id].amount))
            accounts[id].amount = accounts[id].amount - amount
            debugPrint(("New balance: %d"):format(accounts[id].amount))
            TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
            return true
        else
            debugPrint("Insufficient funds for id: " .. id)
        end
    else
        debugPrint("Account not found for id: " .. id)
    end
    return false
end

-- Function to deposit money into the bank
function depositMoney(id, amount)
    debugPrint(("depositMoney called with id: %s, amount: %d"):format(id, amount))
    if accounts[id] then
        if accounts[id].amount >= amount then
            debugPrint(("Previous cash: %d, Previous bank: %d"):format(accounts[id].amount, accounts[id].bank))
            accounts[id].amount = accounts[id].amount - amount
            accounts[id].bank = accounts[id].bank + amount
            debugPrint(("New cash: %d, New bank: %d"):format(accounts[id].amount, accounts[id].bank))
            TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
        else
            debugPrint("Insufficient cash for deposit for id: " .. id)
            TriggerClientEvent('NAT2K15:BANKNOTIFY', id, "Insufficient cash to deposit.")
        end
    else
        debugPrint("Account not found for id: " .. id)
    end
end

-- Function to withdraw money from the bank
function withdrawMoney(id, amount)
    debugPrint(("withdrawMoney called with id: %s, amount: %d"):format(id, amount))
    if accounts[id] then
        if accounts[id].bank >= amount then
            debugPrint(("Previous bank: %d, Previous cash: %d"):format(accounts[id].bank, accounts[id].amount))
            accounts[id].bank = accounts[id].bank - amount
            accounts[id].amount = accounts[id].amount + amount
            debugPrint(("New bank: %d, New cash: %d"):format(accounts[id].bank, accounts[id].amount))
            TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
        else
            debugPrint("Insufficient funds in the bank for id: " .. id)
            TriggerClientEvent('NAT2K15:BANKNOTIFY', id, "Insufficient funds in the bank.")
        end
    else
        debugPrint("Account not found for id: " .. id)
    end
end

-- Event to check or create account in the database
RegisterNetEvent('NAT2K15:CHECKSQL')
AddEventHandler('NAT2K15:CHECKSQL', function(steam, discord, first_name, last_name, dept)
    local src = source
    debugPrint(("CHECKSQL called for source: %s, steam: %s"):format(src, steam))
    if accounts[src] then
        debugPrint("Updating existing account in the database.")
        MySQL.Async.execute("UPDATE money SET bank = @bank, amount = @amount WHERE steam = @steam", {
            ["@bank"] = accounts[src].bank,
            ["@amount"] = accounts[src].amount,
            ["@steam"] = steam
        })
    end

    MySQL.Async.fetchAll("SELECT * FROM money WHERE steam = @steam", { ["@steam"] = steam }, function(data)
        if data[1] == nil then
            debugPrint("No existing account found; creating a new account.")
            MySQL.Async.execute("INSERT INTO money (steam, discord, first, last, dept, bank, amount) VALUES (@steam, @discord, @first, @last, @dept, @bank, @amount)", {
                ["@steam"] = steam,
                ["@discord"] = discord,
                ["@first"] = first_name,
                ["@last"] = last_name,
                ["@dept"] = dept,
                ["@bank"] = config.starting_money,
                ["@amount"] = 0
            })
            accounts[src] = { steam = steam, discord = discord, bank = config.starting_money, amount = 0, dept = dept }
        else
            debugPrint("Account found in the database; loading account data.")
            accounts[src] = { steam = steam, discord = discord, bank = tonumber(data[1].bank), amount = tonumber(data[1].amount), dept = dept }
        end
        TriggerClientEvent('NAT2K15:UPDATECLIENTMONEY', src, accounts[src])
    end)
end)

-- Save account data when a player leaves
AddEventHandler('playerDropped', function()
    local src = source
    debugPrint("playerDropped event for source: " .. src)
    if accounts[src] then
        debugPrint("Saving account data to the database.")
        MySQL.Async.execute("UPDATE money SET bank = @bank, amount = @amount WHERE steam = @steam", {
            ["@bank"] = accounts[src].bank,
            ["@amount"] = accounts[src].amount,
            ["@steam"] = accounts[src].steam
        })
        accounts[src] = nil
    end
end)

-- Pay salary periodically
Citizen.CreateThread(function()
    debugPrint("Starting salary payment thread.")
    while true do
        Citizen.Wait(config.cycle_length * 60 * 1000)
        for _, player in ipairs(GetPlayers()) do
            local src = tonumber(player)
            if accounts[src] and accounts[src].dept then
                debugPrint(("Paying salary for id: %s, dept: %s"):format(src, accounts[src].dept))
                accounts[src].bank = accounts[src].bank + config.deptPay[accounts[src].dept]
                TriggerClientEvent('NAT2K15:UPDATEPAY', src, accounts[src])
            end
        end
    end
end)

-- Exports for external usage
exports('addMoney', addMoney)
exports('deductMoney', deductMoney)
exports('depositMoney', depositMoney)
exports('withdrawMoney', withdrawMoney)

exports('getaccount', function(id)
    debugPrint("getaccount export called for id: " .. id)
    return accounts[id]
end)

exports('updateaccount', function(id, data)
    debugPrint(("updateaccount export called for id: %s"):format(id))
    if accounts[id] then
        accounts[id].amount = data.amount
        accounts[id].bank = data.bank
        TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
    else
        debugPrint("Account not found for id: " .. id)
    end
end)
