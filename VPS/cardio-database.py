#!/usr/bin/python3
#
# ČLB - Návrhy podkladů DB 
#

import sqlite3

DB='cardio.db'

con = sqlite3.connect(DB)
cur = con.cursor()

cur.execute("CREATE TABLE title (text TEXT);")
cur.execute("CREATE TABLE alert (text TEXT);")
cur.execute("CREATE TABLE description (text TEXT);")
cur.execute("""CREATE TABLE cardio (
	id TEXT UNIQUE,
	status INTEGER,
	timestamp TEXT,
	firstname TEXT,
	surname TEXT,
	year TEXT,
	prescription BLOB);"""
)

con.commit()
con.close()

