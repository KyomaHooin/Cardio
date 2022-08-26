#!/usr/bin/python3
#
# ČLB - Návrhy podkladů DB 
#

import sqlite3

DB='cardio.db'

con = sqlite3.connect(DB)
cur = con.cursor()

cur.execute("CREATE TABLE cardio (timestamp TEXT, firstname TEXT, surname TEXT, year TEXT, prescription BLOB);")

cur.execute("CREATE UNIQUE INDEX 'timestamp_index' ON cardio (timestamp);")

con.commit()
con.close()

