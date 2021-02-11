import requests, json
from config import *

BASE_URL = "https://paper-api.alpaca.markets"


BASE_URL = "https://paper-api.alpaca.markets"
ACCOUNT_URL = "{}/v2/account".format(BASE_URL)
ORDERS_URL = "{}/v2/orders".format(BASE_URL)
POSITIONS_URL = "{}/v2/positions".format(BASE_URL)
HEADERS = {'APCA-API-KEY-ID': API_KEY, 'APCA-API-SECRET-KEY': SECRET_KEY}

def get_account():
    r = requests.get(ACCOUNT_URL, headers=HEADERS)
    return json.loads(r.content)

def create_order(symbol, qty, side, type, time_in_force):
    data = {
        "symbol": symbol,
        "qty": qty,
        "side": side,
        "type": type,
        "time_in_force": time_in_force
    }
    r = requests.post(ORDERS_URL, json=data, headers=HEADERS)
    return json.loads(r.content)

def get_orders():
    r = requests.get(ORDERS_URL, headers=HEADERS)
    return json.loads(r.content)

def get_positions():
    r = requests.get(POSITIONS_URL, headers=HEADERS)
    return json.loads(r.content)

def delete_positions(cancel_orders):
    data = {
        "cancel_orders": cancel_orders,
    }
    r = requests.delete(ORDERS_URL, json=data, headers=HEADERS)
    return json.loads(r.content)

#response = create_order("AMC", 100, "buy", "market", "gtc")
#orders = get_orders()
#print(orders)

#positions = get_positions()
#print(positions)

response = delete_positions(True)
