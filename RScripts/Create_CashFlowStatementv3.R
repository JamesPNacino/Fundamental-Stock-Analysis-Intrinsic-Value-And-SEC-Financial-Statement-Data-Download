##### Script to create Cash flow statement data for companies ####
# Note: Must run Get_datav2.R script first 
#### Install packages if haven't already and load packages ####
#install.packages("readxl")
library(readxl)

#### Read in data that includes Cash flow statement tag names ####
#tag names are used for a more consistent naming convention for each balance sheet item
setwd("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing")
tags_df <- data.frame(read_excel("tag_conversion.xlsx")) #manually created excel sheet which includes common balance sheet items
names(tags_df)[names(tags_df) == "tag_SEC"] <- "tag"  #rename column to 'tag'

#### Tasks before looping to create cash flow statement ####
cik_df <- cik_df[cik_df$form=="10-Q" | cik_df$form=="10-K",] #subset where the form is equal to 10-Q or 10-K
tick_loc_df <- loc_df[loc_df$stmt=="CF",] #subset to get only income statement report data
all_tickers <- unique(cik_df$instance) #get the unique tickers
CF_final_df2 <- data.frame() #temporary data frame, used to speed up the loop, data here will be appended to 'CF_final_df3'
CF_final_df3 <- data.frame() #the final income statement will be stored here
count <- 0 #used to track when to append CF_final_df2 to CF_final_df3

#### Loop through each ticker to get cash flow statement data ####
for (i in 1:length(all_tickers)){ 
#for (i in 250:3679){
        count <- count + 1
        
        ticker_df <- cik_df[cik_df$instance==all_tickers[i],] #subset cik_df to get the cik number
        
        #numbers_df shows the financial numbers (values) and associated tags of the inputted ticker
        numbers_df <- fin_df[fin_df$adsh==as.character(ticker_df$adsh[1]),] #get the financial numbers where the unique adsh# is associated to your stock ticker
        if (nrow(numbers_df) == 0){
                next
        }
        
        #tick_loc_df shows the financial statement types and associated tags of the inputted ticker
        CF_tick_loc_df <- tick_loc_df[tick_loc_df$adsh==as.character(ticker_df$adsh[1]),] #get the financial statement type data where the unique adsh# is associated to your stock ticker
        if (nrow(CF_tick_loc_df) == 0){
                next
        }
        
        CF_tick_loc_df$url <- paste("https://www.sec.gov/Archives/edgar/data/", as.character(ticker_df$cik[1]), "/", gsub("-", "", as.character(ticker_df$adsh[1])), sep="")
        CF_tick_loc_df$form <- as.character(ticker_df$form[1]) #create a new column including whether data is 10-Q or 10-k
        CF_tick_loc_df$fy <- ticker_df$fy[1] #create new column to include fiscal year
        CF_tick_loc_df$fq <- ticker_df$fp[1] #create new column to include fiscal quarter
        
        report <- sort(unique(CF_tick_loc_df$report))[1] #the first report is the correct financial statement data for CF data
        CF_tick_loc_df <- CF_tick_loc_df[CF_tick_loc_df$report==report,]
        
        ####This block of code is to get the Cash and Cash Equivalents Ending Balances
        #create a new column which combines the two tags variables with a '---'
        CF_tick_loc_df$cash_vec <- paste(as.character(CF_tick_loc_df$tag), "---", as.character(CF_tick_loc_df$plabel))
        
        
        get_df <- CF_tick_loc_df[grepl("^(Cash).+---.+(E|e){1}(N|n){1}(D|d){1}", CF_tick_loc_df$cash_vec),] #subset data where TRUE, should only be one row
        temp_df <- numbers_df[as.character(numbers_df$tag)==as.character(get_df$tag)[1],]
        if (nrow(temp_df) == 0){
                next
        }
        temp_df <- temp_df[order(temp_df$ddate, decreasing = TRUE),] #order the data because the latest data is equal to the Cash and Cash Equivalents Ending Balances
        temp_df$tag <- as.character(temp_df$tag)
        temp_df$tag[1] <- "CashAndCashEquivalentsEndingBalances"
        numbers_copy_df <- rbind(numbers_df, temp_df[1,]) #the first record/row of temp_df was the latest data, equal to the correct value of cash and cash equivalents to be the ending balances
        CF_tick_loc_df$tag <- ifelse(grepl("^Cash.+---.+(E|e){1}(N|n){1}(D|d){1}", CF_tick_loc_df$cash_vec), "CashAndCashEquivalentsEndingBalances", as.character(CF_tick_loc_df$tag))
        if (!is.na(temp_df$tag[2])){ #the second tag label, if is not 'NA', is not the correct tag. It's the tag that is associated with beggining balances or some other misc. number
                                        #so need to filter the numbers_copy_df where the tag does not include the incorrect tag located in temp_df
                numbers_copy_df <- numbers_copy_df[numbers_copy_df$tag!=temp_df$tag[2],]
        }
        ####
        
        #numbers_df includes all the values of each of the associated tags
        CF_numbers_df <- merge(CF_tick_loc_df, numbers_copy_df, by = "tag", all.x = TRUE) #merge the data together because we want the financial statement type, value, and tags
        
        #if all of the 'values' in the CF_numbers_df are NA, the statement would equal to TRUE and skip to next iteration
        if (length(sort(CF_numbers_df$value))==0){
                print(paste(all_tickers[i], "No numbers data.. skipped"))
                next
        }
        
        date <- CF_numbers_df[CF_numbers_df$tag=="CashAndCashEquivalentsEndingBalances",]$ddate[1] #get the date that we want to work with, should have this tag for the data we want
        if (is.na(date)){
                date <- sort(unique(CF_numbers_df$ddate), decreasing = TRUE)[1] #the latest quarter data is what we want if there is no CashAndCashEquivalentsEndingBalances tag
        }
        CF_numbers_df <- CF_numbers_df[CF_numbers_df$ddate==date,]
        CF_numbers_df <- CF_numbers_df[!is.na(CF_numbers_df$tag),] #remove any tags that were missing after the merge
        
        #CF_numbers_df includes financial statement type, value, and associated tag data
        CF_tags_df <- tags_df[tags_df$financial_statement=="CF",] #selecting only balance sheet data
        CF_df <- merge(CF_numbers_df, CF_tags_df, by = "tag", all.x = TRUE) #merge data to get updated tags located on CF_tags_df
        CF_df$tag <- as.character(CF_df$tag)
        CF_df$tag <- gsub("([[:lower:]])([[:upper:]])", "\\1 \\2", CF_df$tag) #update original tag variable to include spaces between words
        CF_df$tag_renamed <- ifelse(is.na(CF_df$tag_renamed), CF_df$tag, CF_df$tag_renamed) #if the updated tag is not found, then replace with original tag
        CF_df <- CF_df[order(CF_df$line, decreasing = FALSE),] #sort the data according to the correct order
        
        #some more data cleaning
        CF_df$tag_renamed <- sub("^Increase Decrease (I|i)n", "", CF_df$tag_renamed) 
        CF_df$tag_renamed <- sub("^Increase Decreasein", "", CF_df$tag_renamed) 
        
        
        #The IS 'qtrs' variable would always equal to '1' during the first three quarters of the fiscal year
        #The CF 'qtrs' variable would only equal '1' during the first quarter of the fiscal year
        check <- unique(as.character(CF_df$fq))
        if (length(check)>1){
                next
        } else if (check == "FY"){
                CF_df <- CF_df[CF_df$qtrs=="4" | CF_df$qtrs=="0",]
                
        } else {
                temp_qtr <- sub("Q", "", check)
                CF_df <- CF_df[CF_df$qtrs==temp_qtr | CF_df$qtrs=="0",]  #'0' would be the value in the 'qtrs' variable associated with the cash and equivalents ending balance tag regardless if its fiscal year end Q4
        }
        if (nrow(CF_df)==0){
                next
        }

        
        #Create the final Cash flow dataset with only specific columns that we need
        CF_final_df <- data.frame(cbind("tag_sec"=CF_df$tag, "label_sec"=as.character(CF_df$plabel), "report"=CF_df$report, "line"=CF_df$line, 
                                        "stmt"=as.character(CF_df$stmt), "data_date"=CF_df$ddate, "fy"=CF_df$fy,"fq"=as.character(CF_df$fq),
                                        "qtrs"=CF_df$qtrs, "uom"=as.character(CF_df$uom), 
                                        "tag_renamed"=CF_df$tag_renamed, "value"=CF_df$value, "line_item"=CF_df$line_item, "url"=CF_df$url, 
                                        "ein_id"=ticker_df$ein_id[1]))
        
        
        #Do not append data if it does not meet following criteria
        if (as.character(CF_final_df$fq[1]) == "FY" & max(as.character(CF_final_df$qtrs)) != "4"){
                next
        } else if (grepl("Q", as.character(CF_final_df$fq[1]))){ #if quarterly data, then have the 'qtrs' column match the 'fq' column
                temp_qtr <- sub("Q", "", as.character(CF_final_df$fq[1]))
                if (temp_qtr>3 | temp_qtr<=0){ #skip because 'Q3' is the max string quarter. 'Q4' will be represented as 'FY', so skip if 'fq' variable > 3. Should also be now quarter less than or equal to 0
                        next
                }
                CF_final_df <- CF_final_df[CF_final_df$qtrs == temp_qtr | CF_final_df$qtrs=="0",]
                if (nrow(CF_final_df) == 0){
                        next
                }
        } 

        
        #CF_final_df["line_item"][is.na(CF_df["line_item"])] <- "no" #replace NA values with 'no'
        CF_final_df2 <- rbind(CF_final_df2, CF_final_df)
        print(paste(paste("CF-", i, "-", count, sep=""), all_tickers[i], nrow(CF_final_df), as.character(CF_final_df$fq[1]),  max(as.character(CF_final_df$qtrs[1]))))

        #this is used to speed up the loop. When 'count' variable equals 300, rbind CF_final_df2 to the final dataset
        if (count >= 300 & i != length(all_tickers)){
                CF_final_df3 <- rbind(CF_final_df3, CF_final_df2)
                CF_final_df2 <- data.frame()
                count <- 0
        } 
}
if (i == length(all_tickers)){ #if the 'count' variable is equal to the max iteration of the loop, and is less than 300, then rbind CF_final_df2
        # to the final dataset
        CF_final_df3 <- rbind(CF_final_df3, CF_final_df2)

}

#Remove any rows if there are duplicates found in the values of these three colums
CF_final_df3 <- CF_final_df3[!duplicated(CF_final_df3[c("ein_id", "tag_renamed", "value", "data_date")]),]
CF_final_df3 <- CF_final_df3[!is.na(CF_final_df3$value),]