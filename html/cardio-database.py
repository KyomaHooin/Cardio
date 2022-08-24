#!/usr/bin/python3
#
# ČLB - Návrhy podkladů DB 
#

import sqlite3

DB='cardio.db'

con = sqlite3.connect(DB)
cur = con.cursor()

cur.execute("""CREATE TABLE cardio (
		timestamp INTEGER,
		firstname TEXT,
		surname TEXT,
		year INTEGER,
		lek1 TEXT,
		lek2 TEXT,
		lek3 TEXT,
		lek4 TEXT,
		lek5 TEXT,
		lek6 TEXT,
		lek7 TEXT,
		lek8 TEXT,
		lek9 TEXT,
		lek10 TEXT
);""")

cur.execute("CREATE UNIQUE INDEX 'timestamp_index' ON cardio (timestamp);")

con.commit()
con.close()

