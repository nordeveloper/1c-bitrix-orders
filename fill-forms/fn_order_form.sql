-- Function: arc_energo.fn_doc_person_bank(integer)

-- DROP FUNCTION arc_energo.fn_doc_person_bank(integer);

CREATE OR REPLACE FUNCTION arc_energo.fn_order_form(bill_no integer)
  RETURNS character varying AS
$BODY$
from odf.opendocument import load
from odf.table import Table, TableRow, TableCell
from odf import text
from odf.userfield import UserFields
import plpy
from os.path import expanduser

order_items_query = """
SELECT
c."ПозицияСчета"::VARCHAR pg_position
, "Наименование" pg_pos_name
,"Ед Изм" pg_mes_unit
,to_char("Кол-во", '999 999D99') pg_qnt
,to_char("ЦенаНДС", '999 999D99') pg_price
,to_char(round("Кол-во"*"ЦенаНДС", 2), '999 999D99') pg_sum
, "Срок2" pg_period
FROM "Содержание счета" c
WHERE
c."№ счета" = 
""" + str(bill_no) + " ORDER BY pg_position ;"

fld_items = {0: "pg_position", 1: "pg_pos_name", 2: "pg_mes_unit", 3: "pg_qnt", 4: "pg_price", 5: "pg_sum", 6: "pg_period"}


home = expanduser("~")
doc = load(home + u'/fill-forms/order_form_template.odt')
out_dir = u'/mnt/storage'
outfile=out_dir + u'/output/'+ str(bill_no) + u'.odt'

# get 1st table
tab = doc.text.getElementsByType(Table)[1]
rows = tab.getElementsByType(TableRow)

recs = plpy.execute(order_items_query)
#plpy.log("items nrows="+str(recs.nrows()))
#plpy.log("items recs[0]="+str(recs[0]))
for r in range(recs.nrows()):
    cells = rows[r+1].getElementsByType(TableCell)
    cells_header = rows[0].getElementsByType(TableCell)
    plpy.log("r=" + str(r) + ", len(cells)=" + str(len(cells)))
    for cind in range(len(cells)):
        pars = cells[cind].getElementsByType(text.P)
        pars_header = cells_header[cind].getElementsByType(text.P)
        #plpy.log("cind=" + str(cind) +"" +  + ", pars_header=" + pars_header[0].firstChild.__unicode__().encode('utf-8', 'ignore'))
        #plpy.log("cind=" + str(cind) + ", val=" + recs[r][fld_items[cind]].decode('utf-8') )
        pars[0].addText(recs[r][fld_items[cind]].decode('utf-8'))

for row in range(len(recs)+1, len(rows)):
    tab.removeChild(rows[row])

doc.save(outfile)

order_fields_query = """
SELECT
r."Ф_НазваниеКратко" pg_firm
, f."Ф_ИНН" pg_inn
, r."Ф_КПП" pg_kpp
, r."Ф_РассчетныйСчет" || E' в ' || r."Ф_Банк" AS pg_account_bank
, "Ф_КоррСчет" pg_corresp
, "Ф_БИК" pg_bik
, to_char(b."Сумма", '999999999D99') AS pg_amount
, to_char(b."№ счета", '9999-9999') AS pg_order
, to_char(b."Дата счета", 'DD.MM.YYYY') pg_order_date
, e.email pg_email
, e.telephone pg_phone
, e."Имя" pg_mgr_name
FROM "Счета" b
JOIN "Фирма" f ON b."фирма" = f."КлючФирмы"
JOIN "ФирмаРеквизиты" r ON b."фирма" = r."КодФирмы" AND r."Ф_Активность" = TRUE
JOIN "Сотрудники" e ON b."Хозяин" = e."Менеджер"
WHERE
b."№ счета" = 
""" + str(bill_no) + ";"

recs = plpy.execute(order_fields_query)
upd_dict = {}
for (k, v) in recs[0].items():
    upd_dict[k] = v.decode('utf-8')

#dbg_str = "upd_dict=" + str(upd_dict)
#plpy.log(dbg_str)

obj = UserFields(outfile, outfile)
obj.update(upd_dict)


return outfile
$BODY$
  LANGUAGE plpython2u VOLATILE
  COST 100;
ALTER FUNCTION arc_energo.fn_doc_person_bank(integer)
  OWNER TO postgres;