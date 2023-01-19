from myproject import db
from myproject import api

class company(db.Model):

	ein_id = db.Column(db.Integer, primary_key=True)
	adsh = db.Column(db.Text)
	cik_id = db.Column(db.Integer)
	name = db.Column(db.Text)
	sic = db.Column(db.Integer)
	countryba = db.Column(db.Text)
	stprba = db.Column(db.Text)
	cityba = db.Column(db.Text)
	zipba = db.Column(db.Text)
	bas1 = db.Column(db.Text)
	bas2 = db.Column(db.Text)
	baph = db.Column(db.Text)
	countryma = db.Column(db.Text)
	stprma = db.Column(db.Text)
	cityma = db.Column(db.Text)
	zipma = db.Column(db.Text)
	mas1 = db.Column(db.Text)
	mas2 = db.Column(db.Text)
	countryinc = db.Column(db.Text)
	stprinc = db.Column(db.Text)
	former = db.Column(db.Text)
	changed = db.Column(db.Integer)
	afs = db.Column(db.Text)
	wksi = db.Column(db.Integer)
	fye = db.Column(db.Integer)
	form = db.Column(db.Text)
	period = db.Column(db.Integer)
	fy = db.Column(db.Integer)
	fp = db.Column(db.Text)
	filed = db.Column(db.Integer)
	accepted = db.Column(db.Text)
	prevrpt = db.Column(db.Integer)
	detail = db.Column(db.Integer)
	# This is a one-to-many relationship
    # Each instance (ticker) can have many financial records associated with it
    #instance = db.relationship('financial', backpopulates='puppy',lazy='dynamic', uselist = True)
	instance = db.Column(db.Text)
	nciks = db.Column(db.Integer)
	aciks = db.Column(db.Text)
	edgar_year = db.Column(db.Text)


	def __init__(self, instance):
		self.instance = instance

	def __repr__(self):
		return f"This is the data for stock ticker: {self.instance}. Company name: {self.name}"

class financial(db.Model):

	record_id = db.Column(db.Integer, primary_key=True)
	tag_sec = db.Column(db.Text)
	label_sec = db.Column(db.Text)
	report = db.Column(db.Text)
	line = db.Column(db.Text)
	stmt = db.Column(db.Text)
	data_date = db.Column(db.Text)
	fy = db.Column(db.Text)
	fq = db.Column(db.Text)
	qtrs = db.Column(db.Text)
	uom = db.Column(db.Text)
	tag_renamed = db.Column(db.Text)
	value = db.Column(db.Text)
	line_item = db.Column(db.Text)
	url = db.Column(db.Text)

	# connect to the associated company
	# use company.ein_id because tablename is company
	ein_id = db.Column(db.Text, db.ForeignKey(company.ein_id), index=True)


	def __init__(self, ein_id):
		self.ein_id = ein_id

	def __repr__(self):
		#return f"The stock ticker: {self.ein_id}... tag_sec: {self.tag_sec}... value: {self.value}"
		return f"The stock ticker: {self.ein_id}"
