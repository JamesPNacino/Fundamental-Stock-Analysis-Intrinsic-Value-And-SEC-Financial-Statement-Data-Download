# Fundamental-Stock-Analysis-Intrinsic-Value-And-SEC-Financial-Statement-Data-Download

## Summary 

In this application, we will be analyzing the intrinsic value of stocks using various valuation methods. Investors such as Warren Buffet and Benjamin Graham are just a few examples of people who use a fundamental analysis approach to value stocks based upon their intrinsic value. Below I will talk about how this app works and the motivation for this type of automated analyses:

[**Click Here to Go Straight to the App!!**](https://www.financinos.com/)

I have taken a class from [https://www.udemy.com/value-investing-bootcamp-how-to-invest-wisely] which goes over how to go over fundamental stock analysis like those legendary investors mentioned above. The two main valuation methods used in this app are the Discounted Cash Flow and Price-Earning Multiple mode. I needed a way to apply the things learned in this course without having to do manual calculations for every single stock to come up with an intrinsic value estimate. Before using this app it is highly reccommend that you take the class on udemy which was referenced earlier in this paragraph. If you navigate to Steps 2 and 3, that will explain the fundamental analysis and valuation methods that are provided by the application.

Along with stock analysis, the data from the app I created is sourced directly from [**SEC's EDGAR data files**](https://www.sec.gov/dera/data/financial-statement-data-sets.html). There was a lot of data cleaning and formatting which happened prior to using the data for my web app. The only data that is not from the SEC is stock price data, that was via a Yahoo finance API. Another function of this application is for downloading cleaned data of these Edgar data files. In my application I provided an API and CSV download. 

## Cleaning Data Process - Using the R Programming Language

### R Packages

To implement this cleaning process yourself you must download the following packages:

* DBI
* RSQLite
* readXL
* data.table
* XML
* xml2
* httr

### R Scripts - For more info read the README.md in the 'RScripts' folder

* Get_datav3.R
* Get_datav3_loop.R
* Final_cleanv3.R
* Create_BalanceSheetv3.R
* Create_CashFlowStatementv3.R
* Create_IncomeStatementv3.R

## Value Investing Process - Using Python Programming Language

* The code for the Flask web application is found in the 'web_app' folder

1. **Price Earnings Multiple Valuation Method**

o	In this method, a five-year price target is determined based on historical P/E valuation. We will take three inputs to calculate a five-year price target for the company

o	Input 1: Find the median P/E ratio over the past five years. In this example, we will use 19.0

o	Input 2: Find the company’s earnings per share over the most recent four quarters. This may be listed as “EPS (ttm)” or earnings per share trailing twelve months on various sites. This is calculated by just adding these four quarter EPS figures together. In this example, we will use $2.00

o	Input 3: Now estimate a value which you expect the company will grow its profit each year for the next five years. You can use analysts’ growth rate percentage. Make sure to use the Margin of Safety principle to give your estimate room for error. For example, if analysts predict that the company’s profit will grow 10% each year, then use a 15-25% margin of safety buffer. This means that your growth rate estimate will be conservative and if we use a 25% margin of safety buffer, we will arrive at a value of 7.5% (10 percent estimated growth rate * (1 – .25 margin of safety))

o	Now using the three inputs we can arrive at this formula, for a five-year price target (the exponent represents the number of years):

	19 * $2.00 * (1 + .075) ^5 = $54.55 

	This value is what the stock price would be five years from now. To calculate what the stock is worth today, its intrinsic value, we need to discount the five-year price target which gives us the net present value (NPV). 10% is a good discount rate to use because it is equal to the long term historical return of the stock market. It is the minimum rate of return to justify picking a stock over investing in an index fund.

o	To calculate the Net Present Value:

	$54.55 / (1 + .10) ^5 = $33.87

	This, per the P/E valuation model states that the intrinsic value and NPV of that stock is approximately $33.87. 

2. **Discounted Cash Flow Model (DCF)**

o	DCF Model projects future cash flows and discounts them back to the present value; this is a valuation method that estimates the intrinsic value of an investment opportunity. The discount rate represents the riskiness of the company’s capital. You then add up the net present value of the cash flows which is the intrinsic value of the company.

o	Cash flows are generally projected 5-10 years. More mature companies who do not expect as much growth in cash flows, such as Coca Cola will use a 5 year free cash flow projection. In this example we will use a 5-year DCF model.

o	Step 1: Calculate the company’s capital expenditures from the last four quarters. Sum, it up. In this example, we will use $7,207

o	Step 2: Calculate the company’s cash from operating activities. Sum it up. Then in the example, we will use $53,944

o	Step 3: Take the cash from operating activities and subtract it with the capital expenditures. This will give us free cash flow (FCF)

	$53,944 - $7,207 = $46,737

o	Step 4: Then we decide a growth rate of the company for the next five years. This can be analysts’ estimates or your own estimate. If analysts decide that the company will grow at 15.37% each year for the next five years, then it is recommended to use a 25% margin of safety. This means that a conservative growth rate should be (15.37 * (1 - .25)) = 11.53%. 

o	Step 5: So we take our free cash flow of $46,737 and then we multiply it by the conservative growth rate of 11.53% to get the free cash flow one year from now: 

	(46737 * 1.1153) = $52,125 FCF for year one.

o	Step 6: Then we discount this future cash flow value using 10% to get the NPV of the first year’s free cash flow

	$52,125 / (1 + .10)^1 = $47,386 NPV FCF
o	Step 7: Then every year after the first year, we apply the growth decline rate of 5%. So calculating the second year free cash flow:

	$52,125 * (1 + (.1153 * (1-.05))) = $52,125 * 1.1095 = $57,834 FCF for year two

o	Step 8: Then we discount this future cash flow value using 10% to get the NPV of the second year free cash flow

	$52,125 / (1 + .10)^2 = $47,386 NPV FCF

o	Step 9: Continue the process till the year 5 FCF and NPV FCF is calculated.
 
o	Step 10: Take the value of the year 5 FCF, $76,747.49, then you would need to calculate the terminal value which is the company’s long-term valuation as the company approaches perpetuity.

o	Step 11: To calculate the terminal value using the the growth in perpetuity approach you also need to come up with a long-term cash flow growth rate. The long-term growth rate for cash flow in the US economy is around 3%, so we will plug that value in the following formula.

	Terminal value = projected cash flow for final year (1 + long-term growth rate) / (discount rate - long-term growth rate)

	$1,129,284 = $76,747.49 * (1 + .03) / (.1 - .03) 

o	Step 12: Now calculate the net present value of the terminal value. The exponent is the last year that you calculated for the terminal value.

	$1,129,284 / (1 + .1)^5 = $701,196

o	Step 13: Now find the cash and cash equivalents on the balance sheet, in this example we will use, $41,350. Now find long-term debt balance on the balance sheet, in this example, we will use $16,962.

o	Step 14: Take the following inputs and add (subtract debt though) to get the company value using the DCF model.  
 
o	Step 15:  You would then take the company value and then divide it by the number of shares outstanding, which will give you the value of the stock price using the DCF model.
