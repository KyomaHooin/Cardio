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
	last TEXT,
	lock INTEGER);"""
)

cur.execute("INSERT INTO nas(name,ip,last,lock) VALUES('nas1','neznámá adresa', 'neznámý čas', 0);")
cur.execute("INSERT INTO nas(name,ip,last,lock) VALUES('nas2','neznámá adresa', 'neznámý čas', 0);")

con.commit()
con.close()

