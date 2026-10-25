#!/usr/bin/python3
#
# Cardio DB 
#

import sqlite3

DB='nas.db'

con = sqlite3.connect(DB)
cur = con.cursor()

cur.execute("""CREATE TABLE nas (
	name TEXT UNIQUE,
	ip TEXT,
	last TEXT);"""
)

cur.execute("INSERT INTO nas(name,ip,last) VALUES('nas1','neznámá adresa', 'neznámý čas');")
cur.execute("INSERT INTO nas(name,ip,last) VALUES('nas2','neznámá adresa', 'neznámý čas');")

con.commit()
con.close()

