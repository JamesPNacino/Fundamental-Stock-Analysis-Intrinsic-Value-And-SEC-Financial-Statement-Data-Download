from flask import Blueprint,render_template,redirect,url_for, session, send_file, make_response
from myproject import db
from myproject.downloaddata_views.forms import QuerytableForm,DCF_Form, PE_Form
from myproject.models import financial,company
import pandas as pd
from flask_restful import Resource
from myproject import api
import re
import yfinance as yf
import sqlite3
import pandas as pd
import datetime



downloaddata_blueprint = Blueprint('downloaddata_views',
                              __name__,
                              template_folder='templates')


@downloaddata_blueprint.route('/download_data', methods=['GET', 'POST'])
def DOWNLOAD_DATA():

    # import form from forms.py
    form = QuerytableForm()

    # message variable is imported from the LIST_COMPANIES view, the variable exists only once this form has been submitted and LIST_COMPANIES view has been run
    try:
        message = session.get('message', None)
    except NameError: # if the session.get('message', None) variable does not exist yet, assign message variable to None
        message = None
    if (message != None):
        session['message'] = None #Set the session variable to None, so that when people go back to this view, it won't show the error message again
        return render_template('download_data.html', form=form, message=message)

    # if button is clicked on the form
    if form.validate_on_submit():
        # collect data from the inputs
        ticker = form.ticker.data.lower()
        fiscal_period = form.year.data

        # test to see if the company exists in the db, if not then return a message
        company_data = company.query.filter_by(instance=ticker).first()
        if company_data is None:
            message = f"The inputted ticker, {ticker}, was not found in the database"
            return render_template('download_data.html', form=form, message=message)
        elif bool(re.search('^[0-9]{1,15}$', str(company_data.ein_id))) == True: #ticker and year variables will be imported to the following view
            return redirect(url_for('downloaddata_views.LIST_COMPANIES', ticker=ticker, fiscal_period=fiscal_period))

    # Connecting to a template (html file)
    return render_template('download_data.html', form=form)


@downloaddata_blueprint.route('/data_query/<ticker>_<fiscal_period>') #the same arguments in the url 'ticker' and 'year' have to be included in the LIST_COMPANIES view function but not required in the return render_template
def LIST_COMPANIES(ticker, fiscal_period):
    try:
        company_data = pd.read_sql_query(f"SELECT * from company where instance = '{ticker}'", db.get_engine())
        company_data["test"] = company_data["fy"].astype(str) + company_data["fp"] #create a new column that combines fy and fp strings; doing this because one ticker can change their unique ein at any quarter
        company_data["test"] = company_data['test'].str.replace('FY','Q4') #replace 'FY' with 'Q4'
        company_data = company_data[company_data["test"] >= fiscal_period]
        print(company_data)
        company_data = company_data.sort_values(by=['test'], ascending=True) #sort the values with earliest fiscal year on top
        company_data = company_data.reset_index(drop=True) #reset the index because you can only subset specific rows as in the following line if index is reset
        company_data = company_data.iloc[[0]]
        print(company_data)
        ein = company_data['ein_id'].values[0] # get the value from the ein_id column

        fiscal_yr = re.sub("Q[0-9]{1}$", "", fiscal_period)
        fiscal_qtr = re.sub("^[0-9]{4}", "", fiscal_period)
        financials = pd.read_sql_query(f"SELECT * from financial where ein_id = '{ein}' and fy = '{fiscal_yr}' and (fq = '{fiscal_qtr}' or fq = 'FY')", db.get_engine())
        if fiscal_qtr == "Q4":
            financials = financials[(financials['qtrs'] == "0") | ((financials['qtrs'] == "4") & (financials['fq'] == "FY"))]
        else:
            financials = financials[financials['qtrs'] == "0"]

        fiscal_date = max(financials["data_date"])
        format_date = datetime.datetime.strptime(fiscal_date, '%Y%m%d') #specify the format of the original data as a datetime object
        fiscal_date = format_date.strftime("%Y-%m-%d")

        # add the ticker and year variables so they are accessible in list.html
        return render_template('list.html', financials=financials, companies=company_data, ticker=ticker, fiscal_period=fiscal_period, fiscal_date=fiscal_date)
    except: #will activate the except clause if there is an error message with the script above, proably meaning there isn't enough data to perform the calculation
        session['message'] = f'The fiscal data period, {fiscal_period}, was not available for the given stock ticker. Input a different fiscal period'
        return redirect(url_for('downloaddata_views.DOWNLOAD_DATA'))


@downloaddata_blueprint.route('/data_query/download_csv/<ticker>_<fiscal_period>')
def DOWNLOAD_CSV(ticker, fiscal_period):
    company_data = pd.read_sql_query(f"SELECT * from company where instance = '{ticker}'", db.get_engine())
    print(company_data)
    company_data["test"] = company_data["fy"].astype(str) + company_data["fp"] #####TESTING
    print(company_data, fiscal_period)
    company_data["test"] = company_data['test'].str.replace('FY','Q4')
    company_data = company_data[company_data["test"] >= fiscal_period]
    print(company_data)
    company_data = company_data.sort_values(by=['test'], ascending=True)

    company_data = company_data.reset_index(drop=True)

    company_data = company_data.iloc[[0]]
    print(company_data)
    ein = company_data['ein_id'].values[0]
    fiscal_yr = re.sub("Q[0-9]{1}$", "", fiscal_period)
    fiscal_qtr = re.sub("^[0-9]{4}", "", fiscal_period)
    # Get data from financial table via sql query
    financials = pd.read_sql_query(f"SELECT * from financial where ein_id = '{ein}' and fy = '{fiscal_yr}' and (fq = '{fiscal_qtr}' or fq = 'FY')", db.get_engine())
    if fiscal_qtr == "Q4":
        df = financials[(financials['qtrs'] == "0") | ((financials['qtrs'] == "4") & (financials['fq'] == "FY"))]
    else:
        df = financials[financials['qtrs'] == "0"]
    # create csv file
    response = make_response(df.to_csv())
    response.headers["Content-Disposition"] = f"attachment; filename={ticker}_{fiscal_period}.csv"
    response.headers["Content-Type"] = "text/csv"
    return response


@downloaddata_blueprint.route('/valuation_models_DCF', methods=['GET', 'POST'])
def VALUATION_MODELS_DCF():
    # import form from forms.py
    form = DCF_Form()

    # message variable is imported from the VALUATION_MODELS_DCF_LIST view, the variable exists only once this form has been submitted and VALUATION_MODELS_DCF_LIST view has been run
    try:
        message = session.get('message', None)
    except NameError: # if the session.get('message', None) variable does not exist yet, assign message variable to None
        message = None
    if (message != None):
        session['message'] = None #Set the session variable to None, so that when people go back to this view, it won't show the error message again
        return render_template('valuation_models_DCF.html', form=form, message=message)

    # if button is clicked on the form
    if form.validate_on_submit():
        # collect data from the inputs; session is used to store the variable so it can be used in another view
        ticker = form.ticker.data.lower()
        growth_rte = form.growth_rte.data
        decline_rte = form.decline_rte.data
        discount_rte = form.discount_rte.data
        terminal_growth_rt = form.terminal_growth_rt.data
        years_project = form.years_project.data
        fiscal_period = form.fiscal_period.data

        # test to see if the company exists in the db, if not then return a message
        company_data = company.query.filter_by(instance=ticker).first()
        if company_data is None:
            message = f"The inputted ticker, {ticker}, was not found in the database"
            return render_template('valuation_models_DCF.html', form=form, message=message)

        #redirect to the following view if the form has been successfully submitted
        return redirect(url_for('downloaddata_views.VALUATION_MODELS_DCF_LIST', ticker=ticker, growth_rte=growth_rte, decline_rte=decline_rte, discount_rte=discount_rte,
        terminal_growth_rt=terminal_growth_rt, years_project=years_project, fiscal_period=fiscal_period))

    return render_template('valuation_models_DCF.html', form=form)


@downloaddata_blueprint.route('/valuation_models_DCF_list/<ticker>_<fiscal_period>_<growth_rte>_<decline_rte>_<discount_rte>_<terminal_growth_rt>_<years_project>', methods=['GET', 'POST'])
def VALUATION_MODELS_DCF_LIST(ticker, fiscal_period, growth_rte, decline_rte, discount_rte, terminal_growth_rt, years_project):
    try:
        # get the ticker variable data stored from VALUATION_MODELS_DCF view
        ticker = ticker
        growth_rte = growth_rte
        decline_rte = decline_rte
        discount_rte = discount_rte
        terminal_growth_rt = terminal_growth_rt
        years_project = years_project
        fiscal_yr = re.sub("Q[0-9]{1}$", "", fiscal_period)
        fiscal_qtr = re.sub("^[0-9]{4}", "", fiscal_period)
        # query database to get desired data frame
        company_df = pd.read_sql_query(f"SELECT * from company where instance = '{ticker}'", db.get_engine())
        company_df["test"] = company_df["fy"].astype(str) + company_df["fp"] #create a new column, this column will be used to sort because one ticker may have multiple ein numbers but each ein has different reporting period
        print(company_df, fiscal_period)
        company_df["test"] = company_df['test'].str.replace('FY','Q4') #replace FY with Q4
        company_df = company_df[company_df["test"] >= fiscal_period]
        company_df = company_df.sort_values(by=['test'], ascending=True)
        print(company_df)
        company_df = company_df.reset_index(drop=True) #reset the index because unable to grab specific row in below line of code if don't reset index
        company_df = company_df.iloc[[0]] #only get the company row info, where the ein is equal to our desired fiscal data period
        print(company_df)

        ticker_ein = company_df["ein_id"][0]
        #sql query returns a pandas df
        financial_df = pd.read_sql_query(f"SELECT * from financial where ein_id = '{ticker_ein}'", db.get_engine())
        financial_df = financial_df[financial_df["qtrs"] == '0']
        financial_temp_df = financial_df[(financial_df["fy"] == fiscal_yr) & (financial_df["fq"] == fiscal_qtr)]
        print(financial_temp_df["data_date"])
        max_year = max(financial_temp_df["data_date"])

        ###### get all inputs for dcf model ######
        max_df = financial_df[financial_df["data_date"] == max_year]
        fiscal_period = f"{max_df['fy'].values[0]}{max_df['fq'].values[0]}" #should be the same value as the one inputted in the VALUATION_MODELS_DCF view
        # get the price of the share for the latest data period
        max_date = max(max_df["data_date"])
        format_date = datetime.datetime.strptime(max_date, '%Y%m%d') #specify the format of the original data as a datetime object
        start_date = format_date.strftime("%Y-%m-%d")
        end_date = format_date + datetime.timedelta(days=4) #add four days because it could end on a weekend or holiday. Regardless, it returns a dataframe sorting from most recent date up first, so extract first row's data anyway
        end_date = end_date.strftime("%Y-%m-%d")
        # Get the data, downloads a pandas df from yahoo
        data = yf.download(ticker, start_date, end_date)
        # 'data' returns a df object with column variables c(Date, Open, High, Low, Close, Adj Close, Volume)
        current_stock_price = round(data['Close'][0], 2)
        current_stock_price_str = f"${round(data['Close'][0], 2)}" #the closing price of the desired ticker
        # get cash equivalents and more variables
        cash_equivalents = max_df[(max_df['stmt'] == 'BS') & (max_df['tag_renamed'] == 'Cash And Cash Equivalents')]["value"]
        if (len(cash_equivalents) == 0):
            cash_equivalents = max_df[(max_df['stmt'] == 'CF') & (max_df['tag_renamed'] == 'Cash And Cash Equivalents (Ending Balances)')]["value"]
        cash_equivalents = cash_equivalents.values[0]
        long_debt = max_df[(max_df['stmt'] == 'BS') & (max_df['tag_renamed'] == 'Long-term Debt (Non-current)') | (max_df['tag_renamed'] == 'Unsecured Long Term Debt') | (max_df['tag_renamed'] == 'Long Term Debt And Capital Lease Obligations') |
        (max_df['tag_renamed'] == 'Long Term Debt And Capital Lease Obligations Including Current Maturities') | (max_df['tag_renamed'] == 'Long Term Debt') | (max_df['tag_renamed'] == 'Long Term Debt And Finance Leases (Non-current)')]["value"]
        long_debt = long_debt.values[0] #replaced total_liabilities with long_debt for DCF analysis. Keep bottom code just in case want to switch back to total_liabilities
        # total_liabilities = max_df[(max_df['stmt'] == 'BS') & (max_df['tag_renamed'] == 'Total Liabilities')]["value"]
        # if (len(total_liabilities) == 0):
        #     total_stock_equity = max_df[(max_df['stmt'] == 'BS') & (max_df['tag_renamed'] == 'Total Stockholders Equity')]["value"].values[0]
        #     total_stock_equity_liabilities = max_df[(max_df['stmt'] == 'BS') & (max_df['tag_renamed'] == 'Total Liabilities And Stockholders Equity')]["value"].values[0]
        #     total_liabilities = float(total_stock_equity_liabilities) - float(total_stock_equity)
        # else:
        #     total_liabilities = total_liabilities.values[0]
        cash_operating = max_df[(max_df['stmt'] == 'CF') & (max_df['tag_renamed'] == 'Cash Generated By Operating Activities') |
        (max_df['tag_renamed'] == 'Net Cash Provided By Used In Continuing Operations') | (max_df['tag_renamed'] == 'Net Cash Provided By Used In Operating Activities Continuing Operations')]["value"]
        capex = max_df[(max_df['stmt'] == 'CF') & (max_df['tag_renamed'] == 'Payments For Acquisition Of Property, Plant, And Equipment (Capital Expenditures)') |
        (max_df['tag_renamed'] == 'Capital Expenditures Incurred But Not Yet Paid') |
        (max_df['tag_renamed'] == 'Payments To Acquire Productive Assets') |
        (max_df['tag_renamed'] == 'Capital Expenditures Net') |
        (max_df['tag_renamed'] == 'Payments For Proceeds From Productive Assets') |
        (max_df['tag_renamed'] == 'Payments To Acquire Machinery And Equipment') |
        (max_df['tag_renamed'] == 'Capital Expenditures Development Redevelopment') |
        (max_df['tag_renamed'] == 'Payments For Capital Improvements')]["value"]
        print("cash_operating", cash_operating.values[0])
        print("capex", capex.values[0])
        cash_generated_by_operating_activities = float(cash_operating.values[0])
        capex = float(capex.values[0])
        free_cash_flow = cash_generated_by_operating_activities - capex
        free_cash_flow_str = cash_generated_by_operating_activities - capex
        print("test", free_cash_flow)
        shares_outstand = max_df[(max_df['stmt'] == 'BS') & (max_df['tag_renamed'] == 'Shares Outstanding')]["value"]
        shares_outstand = shares_outstand.values[0]
        expected_growth_rate = float(growth_rte)
        growth_decline_rate = float(decline_rte) #the free cash flows will not grow at the same rate every year, will probably decline, so set decline rate
        discount_rate = float(discount_rte)
        terminal_growth_rate = float(terminal_growth_rt) #a value of 2.5-3% is the average growth rate of the economy
        year_projection = int(years_project)#how many years in the future to project the cash flows

        ####### calculate FCFs and NPV FCFs; projecting 5 years into future
        index = [0]
        year = [0]
        FCF = [free_cash_flow]
        FCF_formula = [f"{cash_generated_by_operating_activities} - {capex}"]
        npv_FCF = ["-"]
        npv_FCF_formula = ["-"]
        for i in range(year_projection):
            if (i == 0):
                index.append(i)
                yr = i + 1
                year.append(yr)
                free_cash_flow_formula = f"{free_cash_flow} * (1 + {expected_growth_rate})"
                FCF_formula.append(free_cash_flow_formula)
                free_cash_flow = round(free_cash_flow * (1 + expected_growth_rate), 2)
                FCF.append(free_cash_flow)
                npv = round(free_cash_flow / ((1 + discount_rate)**(yr)), 2)
                npv_FCF.append(npv)
                npv_free_cash_flow_formula = f"{free_cash_flow} / ((1 + {discount_rate})^({yr}))"
                npv_FCF_formula.append(npv_free_cash_flow_formula)
            else:
                index.append(i)
                yr = i + 1
                year.append(yr)
                free_cash_flow_formula = f"{free_cash_flow} * (1 + ({expected_growth_rate} * ((1 - {growth_decline_rate})^({yr} - 1))))"
                FCF_formula.append(free_cash_flow_formula)
                free_cash_flow = round(free_cash_flow * (1 + (expected_growth_rate * ((1 - growth_decline_rate)**(yr - 1)))), 2)
                FCF.append(free_cash_flow)
                npv = round(free_cash_flow / ((1 + discount_rate)**(yr)), 2)
                npv_FCF.append(npv)
                final_year_npv_FCF = npv
                npv_free_cash_flow_formula = f"{free_cash_flow} / ((1 + {discount_rate})^({yr}))"
                npv_FCF_formula.append(npv_free_cash_flow_formula)
            if (i == year_projection-1): #when this is true, then the loop ends right after this if statement
                index.append(i + 1)
                year.append("terminal_value")
                free_cash_flow_formula = f"({free_cash_flow} * (1 + {terminal_growth_rate})) / ({discount_rate} - {terminal_growth_rate})"
                FCF_formula.append(free_cash_flow_formula)
                free_cash_flow = round((free_cash_flow * (1 + terminal_growth_rate)) / (discount_rate - terminal_growth_rate), 2)
                FCF.append(free_cash_flow)
                npv = round(free_cash_flow / ((1 + discount_rate)**(i)), 2)
                npv_FCF.append(npv)
                npv_free_cash_flow_formula = f"{free_cash_flow} / ((1 + {discount_rate})^({yr}))"
                npv_FCF_formula.append(npv_free_cash_flow_formula)

        #create pandas df on the free cash flows that were just calculated
        my_dict = {'index':index, 'year':year, 'FCF':FCF, 'FCF_formula':FCF_formula, 'npv_FCF':npv_FCF, 'npv_FCF_formula':npv_FCF_formula}
        final_df = pd.DataFrame(my_dict)
        print(final_df)
        print(cash_equivalents)
        print(long_debt)
        print("shares_outstand", shares_outstand)

        # calculate the true value of the company based on the calculated cash flows
        sum_npv_CF = round(sum(final_df['npv_FCF'].values[1:(year_projection+2)]), 2)
        company_value = sum_npv_CF + float(cash_equivalents) - float(long_debt)
        company_value = round(company_value, 2)
        company_value_formula = f"{sum_npv_CF}(the sum of the NPV FCFs (includes the terminal value NPV FCFs)) + {float(cash_equivalents)}(Cash and Cash Equivalents) - {float(long_debt)}(Long Term Debt)"
        print('company_value', company_value)
        print('long_debt', long_debt)
        final_year_terminal_npv_FCF_alt = final_year_npv_FCF * 12
        sum_npv_CF_alt = round(sum(final_df['npv_FCF'].values[1:(year_projection+1)]), 2)
        company_value_alt = final_year_terminal_npv_FCF_alt + sum_npv_CF_alt + float(cash_equivalents) - float(long_debt)
        company_value_alt = round(company_value_alt, 2)
        company_value_formula_alt = f"{final_year_terminal_npv_FCF_alt}(terminal value) + {sum_npv_CF_alt}(the sum of the NPV FCFs (w/o terminal value NPV FCFs from table above)) + {float(cash_equivalents)}(Cash and Cash Equivalents) - {float(long_debt)}(Long Term Debt)"
        exit_multiple_valuation = round(company_value_alt / float(shares_outstand), 2)

        #calculate the true value of the stock price based on DCF model
        DCF_stock_price = company_value / float(shares_outstand)
        DCF_stock_price_formula = f"{company_value} / {float(shares_outstand)}"
        DCF_stock_price_str = f"${round(DCF_stock_price, 2)}"

        #determine if the value of the stock is over or under valued based on the DCF model
        if (DCF_stock_price > current_stock_price):
            valuation = ((DCF_stock_price / current_stock_price) - 1) * 100
            valuation_message = f"The price of the stock is currently undervalued by {abs(round(valuation, 2))}%, meaning the stock is currently a buy!"
        elif (DCF_stock_price < current_stock_price):
            valuation = ((current_stock_price / DCF_stock_price) - 1) * 100
            valuation_message = f"The price of the stock is currently overvalued by {abs(round(valuation, 2))}%, meaning the stock is currently a sell!"
        else:
            valuation_message = f"The price of the stock is not currently under or overvalued"

        return render_template('valuation_models_DCF_list.html', cashflow_df=final_df, company=company_df, DCF_value=DCF_stock_price_str, fiscal_period=fiscal_period,
        start_date=start_date, current_stock_price=current_stock_price_str, valuation_message=valuation_message, cash_generated_by_operating_activities=cash_generated_by_operating_activities, capex=capex,
        cash_equivalents=float(cash_equivalents), long_debt=float(long_debt), free_cash_flow_str=free_cash_flow_str, shares_outstand=shares_outstand, expected_growth_rate=expected_growth_rate,
        growth_decline_rate=growth_decline_rate, discount_rate=discount_rate, terminal_growth_rate=terminal_growth_rate, year_projection=year_projection,
        company_value_formula=company_value_formula, company_value=company_value, DCF_stock_price=DCF_stock_price, DCF_stock_price_formula=DCF_stock_price_formula, ticker=ticker, final_year_npv_FCF=final_year_npv_FCF,
        company_value_alt=company_value_alt, company_value_formula_alt=company_value_formula_alt, exit_multiple_valuation=exit_multiple_valuation)
    except: #will activate the except clause if there is an error message with the script above, proably meaning there isn't enough data to perform the calculation
        session['message'] = f'The fiscal data period, {fiscal_period}, was either not available or does not have enough data for the model to perform calculations for the given stock ticker. Input a new stock ticker or different fiscal period'
        return redirect(url_for('downloaddata_views.VALUATION_MODELS_DCF'))



@downloaddata_blueprint.route('/valuation_models_PE', methods=['GET', 'POST'])
def VALUATION_MODELS_PE():
    # import form from forms.py
    form = PE_Form()

    # message variable is imported from the VALUATION_MODELS_PE_LIST view, the variable exists only once this form has been submitted and VALUATION_MODELS_PE_LIST view has been run
    try:
        message = session.get('message', None)
    except NameError: # if the session.get('message', None) variable does not exist yet, assign message variable to None
        message = None
    if (message != None):
        session['message'] = None #Set the session variable to None, so that when people go back to this view, it won't show the error message again
        return render_template('valuation_models_PE.html', form=form, message=message)

    # if button is clicked on the form
    if form.validate_on_submit():
        # collect data from the inputs; session is used to store the variable so it can be used in another view
        ticker = form.ticker.data.lower()
        fiscal_period = form.fiscal_period.data
        growth_rte = form.growth_rte.data
        discount_rte = form.discount_rte.data
        years_project = form.years_project.data

        # test to see if the company exists in the db, if not then return a message
        company_data = company.query.filter_by(instance=ticker).first()
        if company_data is None:
            message = f"The inputted ticker, {ticker}, was not found in the database"
            return render_template('valuation_models_PE.html', form=form, message=message)
        #redirect to the following view if the form has been successfully submitted
        return redirect(url_for('downloaddata_views.VALUATION_MODELS_PE_LIST', ticker=ticker, fiscal_period=fiscal_period, growth_rte=growth_rte, discount_rte=discount_rte, years_project=years_project))

    return render_template('valuation_models_PE.html', form=form)


@downloaddata_blueprint.route('/valuation_models_PE_list/<ticker>_<fiscal_period>_<growth_rte>_<discount_rte>_<years_project>', methods=['GET', 'POST'])
def VALUATION_MODELS_PE_LIST(ticker, fiscal_period, growth_rte, discount_rte, years_project):
    try:
        # retrieve variables from VALUATION_MODELS_PE view
        ticker = ticker
        fiscal_yr = re.sub("Q[0-9]{1}$", "", fiscal_period)
        fiscal_qtr = re.sub("^[0-9]{4}", "", fiscal_period)
        years_project = int(years_project)
        growth_rte = float(growth_rte)
        discount_rte = float(discount_rte)

        # query database to get desired data frame
        company_df = pd.read_sql_query(f"SELECT * from company where instance = '{ticker}'", db.get_engine())
        company_df["test"] = company_df["fy"].astype(str) + company_df["fp"]
        print(company_df, fiscal_period)
        company_df["test"] = company_df['test'].str.replace('FY','Q4')
        company_df = company_df[company_df["test"] >= fiscal_period]
        company_df = company_df.sort_values(by=['test'], ascending=True)
        company_df = company_df.reset_index(drop=True)
        company_df = company_df.iloc[[0]]
        print(company_df)

        ticker_ein = company_df["ein_id"][0]
        #sql query returns a pandas dataframe
        df = pd.read_sql_query(f"SELECT * from financial where ein_id = '{ticker_ein}'", db.get_engine())
        print(df.head())
        df = df[(df["qtrs"] == '0') & (df["stmt"] == "IS")]
        temp_df = df[(df["fy"] == fiscal_yr) & (df["fq"] == fiscal_qtr)]
        max_date = max(temp_df["data_date"])
        df = df[df["data_date"] <= max_date] #only want data less than or equal to the date we need

        # Return all results of query
        print(df)

        ### PE valuation model ###
        # get the maximum data_date of the data dataframe
        max_df = df[df["data_date"] == max_date] #data_date has format e.g. '20090930'
        fiscal_period = f"{max_df['fy'].values[0]}{max_df['fq'].values[0]}" #used for html variable only
        temp_yr = re.sub("[0-9]{4}$", "", max_date)
        temp_yr = int(temp_yr) - 5 #subtract the year by five, because want average of last five years
        temp2_yr = re.sub("^[0-9]{4}", "", max_date)
        temp2_yr = f"{temp_yr}{temp2_yr}"
        df = df[df["data_date"] >= temp2_yr] #subset to get last five years worth of data

        # get the price of the share for the latest data period so that you can input date data into yahoo stock price api
        format_date = datetime.datetime.strptime(max_date, '%Y%m%d') #specify the format of the original data as a datetime object
        start_date = format_date.strftime("%Y-%m-%d") #format the date
        origninal_startdate = start_date
        end_date = format_date + datetime.timedelta(days=4) #add four days because it could end on a weekend or holiday. Regardless, it returns a dataframe sorting from most recent date up first, so extract first row's data anyway
        end_date = end_date.strftime("%Y-%m-%d")

        # Get the data, downloads a pandas df from yahoo
        data = yf.download(ticker, start_date, end_date)
        data2 = round(data['Close'][0], 2) #the closing price of the desired ticker

        # calculate the earnings per share (diluted) (ttm) aka which is last 4 quarters eps summed up
        eps_df = df[df['tag_renamed'] == "EarningsPerShare (Diluted)"]
        eps_df = eps_df.sort_values(by=['data_date'], ascending = False) #order most recent up top, to least recent going down
        eps_df = eps_df[eps_df['value'] != "0"]
        eps_sum = eps_df["value"].iloc[0:4] #get the first four quarter's eps values
        eps_sum = pd.Series(eps_sum, dtype="float64") #convert the pandas series to float
        print(eps_sum)
        eps_sum = round(eps_sum.sum(), 2) #sum the eps values to get ttm (twelve trailing months)
        print(eps_sum)

        # the 'df' dataframe is already subsetted for the last 5 years of data. Get average P/E ratio for last 5 years
        eps_df = eps_df.reset_index()  # have to reset index in order to loop through rows

        pe_list = [] #store the P/E values in the list
        pe_qtr = []# store the P/E values with its associated fy, fq in the list
        for index, row in eps_df.iterrows():
            format_date = datetime.datetime.strptime(row['data_date'], '%Y%m%d') #specify the format of the original data as a datetime object
            start_date = format_date.strftime("%Y-%m-%d")

            end_date = format_date + datetime.timedelta(days=4) #add four days because it could end on a weekend or holiday. Regardless, it returns a dataframe sorting from most recent date up first, so extract first row's data anyway
            end_date = end_date.strftime("%Y-%m-%d")
            print(start_date, end_date)
            stock_df = yf.download(ticker, start_date, end_date)
            stock_price = stock_df['Close'][0]
            pe_value = round(stock_price / float(row['value']), 2) #P/E ratio for a specific date


            #print out P/E ratio
            print(pe_value, stock_price, float(row['value']), row['data_date'])
            pe_list.append(pe_value)
            pe_qtr_value = f"{row['fy']}{row['fq']}: PE Ratio = {round(stock_price, 2)}(stock price)/{round(float(row['value']), 2)}(EPS) = {round(stock_price / float(row['value']), 2)}"
            pe_qtr.append(pe_qtr_value)

        pe_avg = round(sum(pe_list) / len(pe_list), 2) #average P/E ratio over the last five years
        print(pe_avg)
        print(stock_df)
        print(pe_qtr)

        # get p/e valuation and npv of p/e valuation; projecting x years into future where 'x' = years_project
        year = ["0"]
        value = [eps_sum]
        value_formula = ["-"]
        for i in range(years_project):
            if (i == 0):
                EPS_growth = round(eps_sum * (1 + growth_rte), 2)
                year.append(str(i + 1))
                value.append(EPS_growth)
                value_formula.append(f"{eps_sum} * (1 + {growth_rte})")
            else:
                value_formula.append(f"{EPS_growth} * (1 + {growth_rte})")
                EPS_growth = round(EPS_growth * (1 + growth_rte), 2)
                year.append(str(i + 1))
                value.append(EPS_growth)
            if (i == (years_project - 1)): #when i= years_project - 1, after this script below, loop breaks
                valuation = round(EPS_growth * pe_avg, 2)
                valuation_formula = f"{EPS_growth}(EPS (ttm) in {years_project} years) * {pe_avg}(average PE ratio)"
                present_valuation = round(valuation / (1 + discount_rte)**years_project, 2)
                present_valuation_formula = f"{valuation} / (1 + {discount_rte})^{years_project}"
        #create dataframe with EPS values
        my_dict = {'year':year, 'value':value, 'value_formula':value_formula}
        final_PE_df = pd.DataFrame(my_dict)
        print(final_PE_df)
        print(valuation)
        print(present_valuation)
        print(data2)

        #determine if the value of the stock is over or under valued based on the DCF model
        if (present_valuation > data2):
            valuation_message_formula = ((present_valuation / data2) - 1) * 100
            valuation_message = f"The price of the stock is currently undervalued by {abs(round(valuation_message_formula, 2))}%, meaning the stock is currently a buy!"
        elif (present_valuation < data2):
            valuation_message_formula = ((data2 / present_valuation) - 1) * 100
            valuation_message = f"The price of the stock is currently overvalued by {abs(round(valuation_message_formula, 2))}%, meaning the stock is currently a sell!"
        else:
            valuation_message = f"The price of the stock is not currently under or overvalued"

        return render_template('valuation_models_PE_list.html', PE_df=final_PE_df, valuation=valuation, present_valuation=present_valuation, company=company_df, start_date=origninal_startdate,
        current_stock_price=data2, fiscal_period=fiscal_period, npv_valuation=present_valuation, pe_qtr=pe_qtr, pe_avg=pe_avg, eps_sum=eps_sum, growth_rate=growth_rte, discount_rate=discount_rte,
        valuation_formula=valuation_formula, years_project=years_project, present_valuation_formula=present_valuation_formula, valuation_message=valuation_message, ticker=ticker)
    except: #will activate the except clause if there is an error message with the script above, proably meaning there isn't enough data to perform the calculation
        session['message'] = f'The fiscal data period, {fiscal_period}, was either not available or does not have enough data for the model to perform calculations for the given stock ticker. Input a new stock ticker or different fiscal period'
        return redirect(url_for('downloaddata_views.VALUATION_MODELS_PE'))


@downloaddata_blueprint.route('/data_manual')
def DATA_MANUAL():
    return render_template('data_manual.html')


@downloaddata_blueprint.route('/compounding_interest')
def COMPOUNDING_INTEREST():
    return render_template('compounding_interest.html')

@downloaddata_blueprint.route('/ticker_search', methods=['GET', 'POST'])
def TICKER_SEARCH():

    company_df = pd.read_sql_query(f"SELECT * from company", db.get_engine())
    ticker_table = {'Company_Name':company_df['name'], 'Ticker':company_df['instance'], 'Latest_Available_Data_Period':company_df["fy"].astype(str) + company_df["fp"]}
    ticker_table = pd.DataFrame(ticker_table)
    ticker_table["Latest_Available_Data_Period"] = ticker_table['Latest_Available_Data_Period'].str.replace('FY','Q4') #replace 'FY' with 'Q4'
    print(ticker_table)

    # Connecting to a template (html file)
    return render_template('ticker_search.html', ticker_table=ticker_table)



class JSON(Resource):
    def get(self, ticker, fiscal_period): #ticker for example gets its value from <string:ticker> in api.add_resource
        company_data = pd.read_sql_query(f"SELECT * from company where instance = '{ticker}'", db.get_engine())
        company_data["test"] = company_data["fy"].astype(str) + company_data["fp"] #create a new column that combines fy and fp strings; doing this because one ticker can change their unique ein at any quarter
        company_data["test"] = company_data['test'].str.replace('FY','Q4') #replace 'FY' with 'Q4'
        company_data = company_data[company_data["test"] >= fiscal_period]
        company_data = company_data.sort_values(by=['test'], ascending=True) #sort the values with earliest fiscal year on top
        company_data = company_data.reset_index(drop=True) #reset the index because you can only subset specific rows as in the following line if index is reset
        company_data = company_data.iloc[[0]]
        print(company_data)

        ein = company_data['ein_id'].values[0] # get the value from the ein_id column
        address = f"{company_data['bas1'][0]}, {company_data['cityba'].values[0]}, {company_data['stprba'].values[0]} {company_data['countryba'].values[0]} {company_data['zipba'].values[0]}"
        fiscal_yr = re.sub("Q[0-9]{1}$", "", fiscal_period)
        fiscal_qtr = re.sub("^[0-9]{4}", "", fiscal_period)
        #sql query returns a pandas datafame
        financials = pd.read_sql_query(f"SELECT * from financial where ein_id = '{ein}' and fy = '{fiscal_yr}' and (fq = '{fiscal_qtr}' or fq = 'FY')", db.get_engine())
        if fiscal_qtr == "Q4":
            df = financials[(financials['qtrs'] == "0") | ((financials['qtrs'] == "4") & (financials['fq'] == "FY"))]
            print(df)
        else:
            df = financials[financials['qtrs'] == "0"]
            print(df)
        # if df is not empty, return JSON
        if not df.empty:
            return {'Request_summary':{'Company': company_data['name'].values[0], 'Address': address, 'Ticker':ticker, 'EIN_number':str(ein), 'Fiscal_period':fiscal_period},
            'Financials':{'tag_sec':df["tag_sec"].tolist(), 'label_sec':df["label_sec"].tolist(),
            'report':df["report"].tolist(), 'line':df["line"].tolist(), 'stmt':df["stmt"].tolist(),
            'data_date':df["data_date"].tolist(), 'fy':df["fy"].tolist(), 'fq':df["fq"].tolist(), 'qtrs':df["qtrs"].tolist(),
            'uom':df["uom"].tolist(),'tag_renamed':df["tag_renamed"].tolist(), 'value':df["value"].tolist(),
            'line_item':df["line_item"].tolist(), 'url':df["url"].tolist()}}
        else:
            return {'label_sec':None}
api.add_resource(JSON, '/REST/<string:ticker>_<string:fiscal_period>')
