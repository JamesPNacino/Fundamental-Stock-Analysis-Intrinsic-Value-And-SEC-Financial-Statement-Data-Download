from flask_wtf import FlaskForm
from wtforms import StringField, IntegerField, SubmitField, DecimalField

class QuerytableForm(FlaskForm):

	ticker = StringField('Input stock ticker:')
	year = StringField('Input fiscal period (2010Q3):', default="2019Q3")
	submit = SubmitField('Submit')

class DCF_Form(FlaskForm):

	ticker = StringField('Input stock ticker:')
	fiscal_period = StringField('Input the fiscal period for analysis (2010Q3):', default="2019Q3")
	years_project = IntegerField('Input the number of years in the future to project FCFs:', default="5")
	growth_rte = DecimalField('Input the expected FCF growth rate:', default=0.09, places=3)
	decline_rte = DecimalField('Input the rate of decline:', default=0.05, places=3)
	discount_rte = DecimalField('Input the discount rate:', default=0.09, places=3)
	terminal_growth_rt = DecimalField('Input the terminal growth rate (recommend between 2.5-3%):', default=0.025, places=3)
	submit = SubmitField('Submit')

class PE_Form(FlaskForm):

	ticker = StringField('Input stock ticker:')
	fiscal_period = StringField('Input the fiscal period for analysis (2019Q3):', default="2019Q3")
	years_project = IntegerField('Input the number of years in the future to project EPS:', default="5")
	growth_rte = DecimalField('Input the expected EPS growth rate:', default=0.09, places=3)
	discount_rte = DecimalField('Input the discount rate:', default=0.09, places=3)
	submit = SubmitField('Submit')
