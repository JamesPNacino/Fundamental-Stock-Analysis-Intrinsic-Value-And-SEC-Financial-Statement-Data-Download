##### Script to process data that was downloaded from the SEC EDGAR website #####
##Data was downloaded from 'https://www.sec.gov/dera/data/financial-statement-data-sets.html'
#install.packages('RSQLite', repos='http://cran.us.r-project.org', type="binary")
library(DBI)
library(RSQLite)
#"2012", "2013", "2014", "2015", "2016", "2017", "2018", "2019", "2020", "2021"
#temp to loop
ys <- c("2019","2020","2021")
qs <- c("Q1", "Q2", "Q3", "Q4")
for (j in 1:length(ys)){
        for (t in 1:length(qs)){
                Data_year <- paste(ys[j], qs[t], sep="")
                if (qs[t]=="Q1"){
                        previous_qtr <- paste(as.numeric(ys[j])-1, "Q4", sep="")
                } else {previous_qtr <- paste(ys[j], "Q", as.numeric(sub("Q","", qs[t]))-1, sep="")}
                
                #### User Inputs ####
                #Data_year <- "2010Q1" #Input the year of data you want example -> 2012Q2
                #previous_qtr <- "2009Q4" #Input the previous quarter of the data you want
                export_data <- "Yes" #Input either 'Yes' or 'No' to write the data out to a directory. rec'd set to 'Yes'
                db_setup <- "No" #Input 'Yes' or 'No'. 'Yes' means the script will only run 'Create_IncomeStatementv3', 'Create_BalanceSheetv3', 'CreateCashFlowStatementv3', and not 'Final_cleanv3'. Set to 'Yes' when need to first initialize DB with 2009Q4 data
                
                #### Set working directory to where EDGAR financial statement data is located ####
                setwd(paste("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing\\EDGAR_Data\\", sub("Q[1-4]", "", Data_year), "\\", Data_year, sep=""))
                
                #### Read EDGAR data ####
                loc_df <- read.csv("pre.txt", sep="\t", quote = "", header=TRUE) #Dataset where you see the various financial statement types and report locations online if need be
                cik_df <- read.csv("sub.txt", sep="\t", quote = "", header=TRUE) #Dataset which shows cik data (unique business identifier) and company info, etc
                fin_df <- read.csv("num.txt", sep="\t", quote = "", header=TRUE) #Dataset with financial statement data, the numbers/figures themselves to each tag
                
                if (Data_year != "2009Q4"){ #only run after the first data load in the database, which is 2009Q4 data
                        ### Get the ticker from the previous data load, and if ein and company name match from previous load to cik_df, then change ticker in cik_df to match previous load ticker
                        # Do this because the instance may be formatted for Apple in 2019Q3, as "a10-qq320196292019_htm.xml".. same with Google.. probably more so get correct ticker from previous load
                        directory_2 <- "C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing\\web_app\\myproject"
                        setwd(directory_2)
                        #connect to database
                        con <- dbConnect(RSQLite::SQLite(), "financials_db.sqlite")
                        cik2_df <- data.frame(dbGetQuery(con, "SELECT * FROM company")) #read company data from previous load
                        dbDisconnect(con)
                        unq_ein <- unique(cik_df$ein)
                        for (i in 1:length(unq_ein)){
                                temp_df <- cik_df[cik_df$ein==unq_ein[i],]
                                temp_df <- temp_df[!is.na(temp_df$ein),]
                                temp2_df <- cik2_df[cik2_df$ein_id==unq_ein[i],]
                                temp2_df <- temp2_df[!is.na(temp2_df$ein_id),]
                                if (nrow(temp2_df)>0 & !is.na(temp2_df$ein_id[1])){
                                        if (as.character(temp_df$ein[1])==as.character(temp2_df$ein_id[1]) & as.character(temp_df$name[1])==as.character(temp2_df$name[1])){
                                                cik_df$instance <- ifelse(cik_df$ein==unq_ein[i], as.character(temp2_df$instance[1]), as.character(cik_df$instance))
                                        }
                                        
                                }
                        }
                }
                
                #### Clean data ####
                #fin_df$value <- format(fin_df$value, scientific = F)
                fin_df$value <- sub(" +", ".", fin_df$value) #removing any blank space after the values
                cik_df$instance <- sub("-.+", "", cik_df$instance) #Clean 'instance' variable (this variable shows the stock ticker)
                cik_df <- cik_df[!grepl(".xml", cik_df$instance),] #filter data frame to not include '.xml' files
                cik_df$instance <- sub("_.+", "", cik_df$instance) 
                cik_df <- cik_df[!grepl("[0-9]", cik_df$instance),] #filter data frame to not include any numbers
                cik_df <- cik_df[cik_df$form=="10-Q" | cik_df$form=="10-K",] #subset where the form is equal to 10-Q or 10-K
                cik_df <- cik_df[!duplicated(cik_df[c("instance")]),] #remove duplicate rows that have duplicate tickers
                cik_df <- cik_df[!duplicated(cik_df[c("cik")]),] #remove duplicate rows that have duplicate cik
                cik_df <- cik_df[!duplicated(cik_df[c("ein")]),] #remove duplicate rows that have duplicate ein
                colnames(cik_df)[colnames(cik_df) == 'cik'] <- 'cik_id' #change column names
                colnames(cik_df)[colnames(cik_df) == 'ein'] <- 'ein_id'
                cik_df <- cik_df[!is.na(cik_df$ein_id),]
                cik_df <- cik_df[!is.na(cik_df$fy),]
                cik_df <- cik_df[!is.na(cik_df$fp),]
                cik_df$edgar_year <- Data_year
                
                #Run scripts to get Income Statement, Balance Sheet, Cash Flow Statement data
                setwd("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing")
                source("Create_IncomeStatementv3.R")
                source("Create_BalanceSheetv3.R")
                source("Create_CashFlowStatementv3.R")
                
                #Combine all final data sets
                final_df <- data.frame(rbind(IS_final_df3, BS_final_df3, CF_final_df3))
                final_df$tag_sec <- sub("^ {1,100}", "", final_df$tag_sec) #remove any white space in the beginning
                final_df$label_sec <- sub("^ {1,100}", "", final_df$label_sec) #remove any white space in the beginning
                final_df$tag_renamed <- sub("^ {1,100}", "", final_df$tag_renamed) #remove any white space in the beginning
                final_df <- final_df[order(as.character(final_df$ein_id), decreasing = FALSE),]
                final_df <- final_df[!is.na(final_df$ein_id),]
                #final_df$record_id <- seq.int(nrow(final_df)) #create an id column incrementing by one. e.g. row 1 has value 1, row 2 has value 2
                
                
                # Write out CSV files with data
                directory <- paste("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing\\EDGAR_ProcessedData\\", Data_year, sep="")
                if (export_data == "Yes"){
                        if (dir.exists(directory)){
                                write.csv(cik_df, paste(directory , "\\", Data_year, "_CompanyInfo.csv", sep=""), row.names=FALSE)
                                write.csv(fin_df, paste(directory , "\\", Data_year, "_numbers.csv", sep=""), row.names=FALSE)
                                write.csv(final_df, paste(directory , "\\", Data_year, "_FinalData.csv", sep=""), row.names=FALSE)
                        } else {
                                dir.create(directory)
                                write.csv(cik_df, paste(directory , "\\", Data_year, "_CompanyInfo.csv", sep=""), row.names=FALSE)
                                write.csv(fin_df, paste(directory , "\\", Data_year, "_Numbers.csv", sep=""), row.names=FALSE)
                                write.csv(final_df, paste(directory , "\\", Data_year, "_FinalData.csv", sep=""), row.names=FALSE)
                        }
                }
                
                #When db_setup equals 'No', means not running 'Final_cleanv3', hence also not uploading data into database. Set to 'No' only when you run 2009Q4 data, because need to manually insert this data into database
                if (db_setup == "No"){
                        
                        #### Run final data cleaning script ####
                        directory_2 <- paste("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing\\web_app\\myproject", sep="")
                        #directory_2 <- paste("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing\\EDGAR_ProcessedData\\Combined_final_data", sep="")
                        if (!dir.exists(directory_2)){ #create the directory if it doesn't exist
                                dir.create(directory_2)
                        }
                        
                        setwd(directory_2)
                        #connect to database
                        con <- dbConnect(RSQLite::SQLite(), "financials_db.sqlite")
                        cik2_df <- data.frame(dbGetQuery(con, "SELECT * FROM company"))
                        ein <- as.character(cik2_df$ein_id) #unique values of ein numbers
                        for (i in 1:length(ein)){ #if an ein number is found in the previous data load, but not in the current data, than add that previous load ein's data
                                if (!is.element(ein[i], cik_df$ein_id)){
                                        temp_df <- cik2_df[cik2_df$ein_id==ein[i],] #subset data to get that row
                                        #ticker <- temp_df$instance[1] #get the instance value
                                        #temp2_df <- cik_df[cik_df$instance == ticker,]
                                        cik_df <- rbind(cik_df, temp_df) #will lead to duplicate tickers in the database, but sometimes a company changes ein number
                                        
                                }
                        }
                        test <- as.character(dbGetQuery(con, "SELECT MAX(edgar_year) FROM company"))
                        if (test == previous_qtr){
                                setwd("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing")
                                source("Final_cleanv3.R")
                                if (export_data == "Yes"){
                                        if (dir.exists(directory_2)){
                                                print("Deleting previous data in company table")
                                                dbExecute(con, " DELETE from company")
                                                
                                                print("Replacing and inserting new data in company table")
                                                dbWriteTable(con, "company", cik_df, append = TRUE, row.names = FALSE, overwrite = FALSE)
                                                print("Appending new data in financial table")
                                                dbWriteTable(con, "financial", final3_df, append = TRUE, row.names = FALSE, overwrite = FALSE)
                                                
                                                print(paste("DB successfully refreshed with ", Data_year, " data! closing connection", sep=""))
                                                dbDisconnect(con)
                                        }
                                }
                        } else {print("previous data period should be the max data period in your DB. Following was the maximum data period found in your DB..")
                                print(paste(test, "company table"))
                        }
                }
                if (db_setup == "Yes"){
                        directory_2 <- paste("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing\\web_app\\myproject", sep="")
                        #directory_2 <- paste("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing\\EDGAR_ProcessedData\\Combined_final_data", sep="")
                        if (!dir.exists(directory_2)){ #create the directory if it doesn't exist
                                dir.create(directory_2)
                        }
                        
                        setwd(directory_2)
                        #connect to database
                        con <- dbConnect(RSQLite::SQLite(), "financials_db.sqlite")
                        cik2_df <- data.frame(dbGetQuery(con, "SELECT * FROM company"))
                        
                        
                        print("Replacing and inserting new data in company table")
                        dbWriteTable(con, "company", cik_df, append = TRUE, row.names = FALSE, overwrite = FALSE)
                        print("Appending new data in financial table")
                        dbWriteTable(con, "financial", final_df, append = TRUE, row.names = FALSE, overwrite = FALSE)
                        dbDisconnect(con)
                }
                ########################################
                
                # The Income Statement and Cash Flow Statement appear to be cumulative figures
                #income statement shows each quarter data as well as cumulative figures. Except for FY end, only shows cumulative
                #cash flow only shows cumulative
                # The Balance Sheet Appears to be for each quarter

        }
}
