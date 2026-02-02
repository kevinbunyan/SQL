# this script will populate a database which has 10 customers, 10 products and 3000 events over a 90 day window. It will also set some values to 0 and some to - to study missing values and values that are inconsistent. 
# the only requirements are a blank SQL server database called live
# the script is idempotent - it will drop and rebuild all views, functions, stored procedures and tables and will fully repopulate 
