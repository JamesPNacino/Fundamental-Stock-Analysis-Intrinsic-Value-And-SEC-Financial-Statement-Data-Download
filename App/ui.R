##Shiny UI

# Use a fluid Bootstrap layout
fluidPage(    
        
        # Give the page a title
        titlePanel("Fundamental Stock Analysis"),
        
        # Generate a row with a sidebar
        sidebarLayout(      
                
                # Define the sidebar layout
                sidebarPanel(
                        textInput(inputId = "ticker", label = "Stock Ticker(s):", value = paste(c("MSFT","GOOG","AMZN"), collapse=",")),
                        helpText("Enter Stock Tickers, separated by commas, no spaces. Recommended to not input more than four stock tickers. Please be patient as the data takes a little while to load."),
                        hr(),
                        
                        sliderInput(inputId = "ExpectedGrowthRate", label = "Expected Growth Rate:", min = -.01, max = .30, value = -.01, step = .01),
                        helpText("When the expected growth rate is negative, the growth rate is equal to the slope of the regression line (Date used as sole independent variable.)"),
                        hr(),
                                                
                        sliderInput(inputId = "MarginSafety", label = "Margin of Safety", min = 0, max = .30, value = .10, step = .01),
                        helpText("The margin of safety is applied to the expected growth rate, to come up with a conservative growth rate estimate."),
                        hr(),
                        
                        sliderInput(inputId = "GrowthDeclineRate", label = "Growth Decline Rate:", min = 0, max = .15, value = .05, step = .01),
                        helpText("Growth decline rate is applied to the conservative growth rate one year after first year projections. This is because it is hard to keep consistent high growth rates in the long run."),
                        hr(),
                        
                        sliderInput(inputId = "DiscountRate", label = "Discount Rate:", min = 0, max = .20, value = .09, step = .01),
                        helpText("Discount rate initially set to .09 because 9% rate of return is the historic long term growth of the stock market."),
                        hr(),
                        
                        sliderInput(inputId = "DCF_YearsProjection", label = "DCF Valuation Model. Number of years in future to project:", min = 5, max = 10, value = 5, step = 1),
                        helpText("Generally you would project a company's cash flows five to ten years in the future."),
                        hr(),
                        
                        sliderInput(inputId = "LongTermGrowthRate", label = "Long Term Cash Flow Growth Rate:", min = 0.01, max = .05, value = .03, step = .01),
                        helpText("The long term cash flow growth rate in the US economy is around three percent."),
                        hr(),
                        
                        submitButton(text = "Analyze")
                        ),
                
                
                
                # Create a spot for the barplot
                mainPanel(
                        tabsetPanel(
                                tabPanel("Discounted Cash Flow Valuation Model",
                                         tabsetPanel(
                                                 tabPanel("Analysis",
                                                          p("Due to the amount of data being loaded and read, this app may take a couple seconds to load for each tab..."),
                                                          plotOutput("DCF_Model.plot"),
                                                          p("The DCF Model projects future cash flows and discounts them back to the present value; this is a valuation method that estimates the intrinsic value of an investment opportunity."),
                                                          hr(),
                                                          plotOutput("DCF_Model.plot2"),
                                                          p("Generally recommended to look for a company with stable or increasing cash flows over time. The free cash flows of a company are hard to maintain at a high growth rate, so each year, the conservative growth rate will decline by the growth decline rate. Free cash flow is used for paying debts, dividends, buybacks, or investing in the future growth of a company.")), 
                                                 tabPanel("Data/Calculations",
                                                          h2("DCF Valuation Table"),
                                                          dataTableOutput("DCF_Model.table2"),
                                                          hr(),
                                                          h2("Free Cash Flows Projection and Values Table "),
                                                          dataTableOutput("DCF_Model.table")))),
                                
                                
                                tabPanel("Price Earnings Multiple Valuation Model",
                                         tabsetPanel(
                                                 tabPanel("Analysis",
                                                          plotOutput("PE_Model.plot"),
                                                          p("In this method, a five-year price target is determined based on historical P/E valuation."),
                                                          hr(),
                                                          plotOutput("PE_Model.plot2"),
                                                          p("The Earnings per share is the profit that a company makes per share of stock. A growing EPS is better than it decreasing or staying stable. Calculated by dividing 'Net Income / Shares Outstanding'.")), 
                                                 tabPanel("Data/Calculations",
                                                          h2("PE Valuation Table"),
                                                          dataTableOutput("PE_Model.table"),
                                                          hr(),
                                                          h2("EPS Table"),
                                                          dataTableOutput("PE_Model.table2")))),
                                
                                
                                tabPanel("Fundamental Analysis",
                                         tabsetPanel(
                                                 tabPanel("Analysis",
                                                          plotOutput("Cash_Equivalents.plot"),
                                                          p("Generally recommended to look for Cash and Equivalents to increase over time. Reported on the balance sheet. An increasing value means that there is more cash reserves over time. Even if this metric is decreasing over time, the company can just be investing the reserve money to improve the business."),
                                                          hr(color="black"),
                                                          plotOutput("Book_Value.plot"),
                                                          p("Generally recommended to look for book value to increase over time. This shows how much money, you would receive for your shares of stock if the company liquidates, selling all of its assets after paying off its debts. You want to look for companies with increasing book value per share because they are companies that are creating value. To calculate: 'Shareholders Equity / Shares Outstanding'."),
                                                          hr(),
                                                          plotOutput("Net_Margin.plot"),
                                                          p("Generally recommended to look for net margin to increase over time. Net margin is what percent of sales is profit. This figure differs greatly from industry to industry. If a company is able to sustain high profit margins, then the company may have a strong brand name or patented products that competitors can't compete with. The higher the net margin, the better. To calculate 'Net Income / Revenue'."),
                                                          hr(),
                                                          plotOutput("Return_Equity.plot"),
                                                          p("Generally recommended that return on equity is consistently high. Return on equity tells us how efficiently a company uses its assets to generate earnings. The higher the return on equity, the better. To calculate: 'Net Income / Shareholders Equity"),
                                                          hr(),
                                                          plotOutput("Debt_Equity.plot"),
                                                          p("Generally recommended to look for debt to equity that has been consistently low or decreasing. Long term debt to equity ratio indicates how much debt a company in relation to its shareholder's equity. High debt levels are a huge warning sign as it relies on debt to finance its growth. If a company has an increasing debt to equity ratio, then the investment may become risky because the company cannot meet its debt obligations. To calculate: 'Long-Term Debt / Shareholders Equity'")), 
                                                 tabPanel("Data/Calculations",
                                                          h2("Cash Equivalents Table"),
                                                          dataTableOutput("Cash_Equivalents.table"),
                                                          hr(),
                                                          h2("Book Value per Share Table"),
                                                          dataTableOutput("Book_Value.table"),
                                                          hr(),
                                                          h2("Net/Profit Margin Table"),
                                                          dataTableOutput("Net_Margin.table"),
                                                          hr(),
                                                          h2("Return on Equity Table"),
                                                          dataTableOutput("Return_Equity.table"),
                                                          hr(color="black"),
                                                          h2("Long Term Debt to Equity Table"),
                                                          dataTableOutput("Debt_Equity.table")))),
                                
                                
                                
                                tabPanel("Financial Statements",
                                         dataTableOutput("FinanceData.table")),
                                
                                tabPanel("More Details")
                        ) 
                )
                
        )
)