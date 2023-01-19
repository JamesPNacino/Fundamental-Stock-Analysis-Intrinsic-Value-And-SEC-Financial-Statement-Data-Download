##### Script to create balance sheet data for companies ####
# Note: Must run Get_datav2.R script first 
#### Install packages if haven't already and load packages ####
#install.packages("readxl")
library(readxl)
library(xml2)
library(XML)
library(httr)

#### Read in data that includes Balance Sheet tag names ####
#tag names are used for a more consistent naming convention for each balance sheet item
setwd("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing")
tags_df <- data.frame(read_excel("tag_conversion.xlsx")) #manually created excel sheet which includes common balance sheet items
names(tags_df)[names(tags_df) == "tag_SEC"] <- "tag"  #rename column to 'tag'

#### Tasks before looping to create balance sheet data ####
cik_df <- cik_df[cik_df$form=="10-Q" | cik_df$form=="10-K",] #subset where the form is equal to 10-Q or 10-K
tick_loc_df <- loc_df[loc_df$stmt=="BS" | (loc_df$stmt=="CP" & loc_df$tag=="EntityCommonStockSharesOutstanding"),] #subset to get only balance sheet report data and shares outstanding
all_tickers <- unique(cik_df$instance) #get the unique tickers
#all_tickers <- "mcs" #msft test
#all_tickers <- c("bsm", "nacco")
BS_final_df2 <- data.frame() #temporary data frame, used to speed up the loop, data here will be appended to 'BS_final_df3'
BS_final_df3 <- data.frame() #the final income statement will be stored here
count <- 0 #used to track when to append BS_final_df2 to BS_final_df3

#### Loop through each ticker to get balance sheet data ####
for (i in 1:length(all_tickers)){ 
        count <- count + 1
        
        ticker_df <- cik_df[cik_df$instance==all_tickers[i],] #subset cik_df to get the cik number
        #25
        #numbers_df shows the financial numbers (values) and associated tags of the inputted ticker
        numbers_df <- fin_df[fin_df$adsh==as.character(ticker_df$adsh[1]),] #get the financial numbers where the unique adsh# is associated to your stock ticker
        if (nrow(numbers_df) == 0){
                next
        }
        
        #tick_loc_df shows the financial statement types and associated tags of the inputted ticker
        BS_tick_loc_df <- tick_loc_df[tick_loc_df$adsh==as.character(ticker_df$adsh[1]),] #get the financial statement type data where the unique adsh# is associated to your stock ticker
        if (nrow(BS_tick_loc_df) == 0){
                next
        }
        shares_out_df <- BS_tick_loc_df[BS_tick_loc_df$tag=="EntityCommonStockSharesOutstanding",] #add shares outstanding later on in script
        BS_tick_loc_df <- BS_tick_loc_df[BS_tick_loc_df$stmt=="BS",] #filter out shares outstanding because its located on different stmt
        if (nrow(BS_tick_loc_df) == 0){ #including a second time because after filtering stmt for BS, the df may be empty
                next
        }
        
        BS_tick_loc_df$url <- paste("https://www.sec.gov/Archives/edgar/data/", as.character(ticker_df$cik[1]), "/", gsub("-", "", as.character(ticker_df$adsh[1])), sep="")
        BS_tick_loc_df$form <- as.character(ticker_df$form[1]) #create a new column including whether data is 10-Q or 10-k
        BS_tick_loc_df$fy <- ticker_df$fy[1] #create new column to include fiscal year
        BS_tick_loc_df$fq <- ticker_df$fp[1] #create new column to include fiscal quarter
        
        report <- sort(unique(BS_tick_loc_df$report))[1] #the first report are the correct financial statement data for shares outstanding and BS data
        BS_tick_loc_df <- BS_tick_loc_df[BS_tick_loc_df$report==report,]
        
        #numbers_df includes all the values of each of the associated tags
        BS_numbers_df <- merge(BS_tick_loc_df, numbers_df, by = "tag", all.x = TRUE) #merge the data together because we want the financial statement type, value, and tags
        shares_out_df <- merge(shares_out_df, numbers_df, by = "tag", all.x = TRUE)
        
        #if all of the 'values' in the BS_numbers_df are NA, the statement would equal to TRUE and skip to next iteration
        if (length(sort(BS_numbers_df$value))==0){
                print(paste(all_tickers[i], "No numbers data.. skipped"))
                next
        }
        
        date <- sort(unique(BS_numbers_df$ddate), decreasing = TRUE)[1] #the latest quarter data is what we want
        BS_numbers_df <- BS_numbers_df[BS_numbers_df$ddate==date,] #sort greater than or equal to because shares outstanding may have later date
        BS_numbers_df <- BS_numbers_df[!is.na(BS_numbers_df$tag),] #remove any tags that were missing after the merge
        
        #BS_numbers_df includes financial statement type, value, and associated tag data
        BS_tags_df <- tags_df[tags_df$financial_statement=="BS",] #selecting only balance sheet data
        BS_df <- merge(BS_numbers_df, BS_tags_df, by = "tag", all.x = TRUE) #merge data to get updated tags located on BS_tags_df
        BS_df$tag <- as.character(BS_df$tag)
        BS_df$tag <- gsub("([[:lower:]])([[:upper:]])", "\\1 \\2", BS_df$tag) #update original tag variable to include spaces between words
        BS_df$tag_renamed <- ifelse(is.na(BS_df$tag_renamed), BS_df$tag, BS_df$tag_renamed) #if the updated tag is not found, then replace with original tag
        BS_df <- BS_df[order(BS_df$line, decreasing = FALSE),] #sort the data according to the correct order
        BS_df$tag_renamed <- sub(" Current$", " (Current)", BS_df$tag_renamed) #perform more data cleaning
        BS_df$tag_renamed <- sub(" Noncurrent$", " (Non-current)", BS_df$tag_renamed)
        
        #Create the final Balance Sheet dataset with only specific columns that we need
        BS_final_df <- data.frame(cbind("tag_sec"=as.character(BS_df$tag), "label_sec"=as.character(BS_df$plabel), "report"=as.character(BS_df$report), "line"=as.character(BS_df$line), 
                                        "stmt"=as.character(BS_df$stmt), "data_date"=as.character(BS_df$ddate), "fy"=as.character(BS_df$fy),"fq"=as.character(BS_df$fq),
                                        "qtrs"=as.character(BS_df$qtrs), "uom"=as.character(BS_df$uom), 
                                        "tag_renamed"=as.character(BS_df$tag_renamed), "value"=as.character(BS_df$value), "line_item"=as.character(BS_df$line_item), "url"=as.character(BS_df$url), 
                                        "ein_id"=ticker_df$ein_id[1]))
        if (nrow(shares_out_df)==1){ #should only have one row
        
                #rbind shares outstanding data
                shares_out_df <- data.frame("tag_sec"="Entity Common Stock Shares Outstanding", "label_sec"=as.character(shares_out_df$plabel), "report"=as.character(shares_out_df$report)[1], 
                                            "line"=as.character(shares_out_df$line)[1], 
                                            "stmt"="BS", "data_date"=unique(as.character(BS_final_df$data_date))[1], "fy"=unique(as.character(BS_final_df$fy))[1],"fq"=unique(as.character(BS_final_df$fq))[1],
                                            "qtrs"="0", "uom"="shares", 
                                            "tag_renamed"="Shares Outstanding", "value"=shares_out_df$value[1], "line_item"="yes", "url"=BS_df$url[1], 
                                            "ein_id"=ticker_df$ein_id[1])
                #BS_final_df <- BS_final_df[BS_final_df$tag_sec != "Entity Common Stock Shares Outstanding",] #BS_final_df shouldn't have the shares outstanding tag prior to the rbind of BS_final_df and shares_out_df, but it can happen, so prevent it
                BS_final_df <- rbind(BS_final_df, shares_out_df)
                
                # get the value of shares outstanding, if it is 'NA' value, it usually means the ticker has class A and B. So get XML data online
                SO_df <- BS_final_df[BS_final_df$tag_sec == "Entity Common Stock Shares Outstanding",]
                SO_value <- as.character(SO_df$value)
                if (nrow(SO_df)==1){
                
                        ########## there are limits on how often can request data from EDGAR
                        if (is.na(SO_value)){  
                        #try at least four times to get html data, should usually get data on 1st try but sometimes request may not go through due to busy server
                        html <- c(NA,NA)
                        for (t in 1:4){
                                # if html is still NA on first iteration
                                if (t > 1){
                                        # wait for 0.5 seconds before executing next iteration
                                        Sys.sleep(0.5)
                                        print(paste("Trying again.. attempt ", t, sep=""))
                                }
                                if (is.na(html[1])){
                                        html <- tryCatch({GET(paste(as.character(SO_df$url[1]), "/R", as.character(SO_df$report[1]), ".htm", sep=""), 
                                                              add_headers('User-Agent' = "Personal_project jamespnacino@hotmail.com"))}, #Get request 
                                                         error = function(e){
                                                                 print("Error requesting shares outstanding data")
                                                                 return(c(NA,NA))
                                                         })
                                        if (!is.na(html[1])){break}
                                }
                        }
                                if (!is.na(html[1])){
                                        tryCatch( #the shares outstanding code appears to work starting 2015Q1, and appears to have some errors for some stock tickers before that fiscal data, set SO_vals to NA if error
                                                expr = {
                                                        # the retrieved html will have headers, such as $status_code
                                                        if (html$status_code!='404'){
                                                                text <- content(html, as="text", encoding="UTF-8") #Retrieve contents of the request
                                                                parsedHtml <- htmlParse(text, asText = TRUE) #parse text as html
                                                                title <- xpathSApply(parsedHtml, "//title", xmlValue)
                                                                if (grepl("Request Rate Threshold Exceeded", title)){
                                                                        print("Request Rate Threshold Exceeded")
                                                                } else {
                                                                        SO_vals <- xpathSApply(parsedHtml, "//tr[@class='ro']", xmlValue)
                                                                        SO_vals2 <- xpathSApply(parsedHtml, "//tr[@class='re']", xmlValue)
                                                                        SO_vals <- append(SO_vals, SO_vals2)
                                                                        SO_vals <- gsub(",", "", SO_vals) #removes all commas
                                                                        SO_vals <- toupper(SO_vals)
                                                                        SO_vals <- SO_vals[grepl("ENTITY COMMON STOCK SHARES OUTSTANDING|SHARES OUTSTANDING", SO_vals)] #match/get only shares outstanding text from vector
                                                                        SO_vals <- gsub("\\D+", "", SO_vals) #removes all non-numeric digits in a string/vector of strings
                                                                        SO_vals <- sum(as.numeric(SO_vals)) #sum the shares outstanding values
                                                                        if (SO_vals == "0"){ #if shares outstanding value is zero
                                                                                SO_vals <- NA
                                                                        }
                                                                }
                                                                
                                                        }
                                                        if (html$status_code=='404'){
                                                                #set SO_vals to NA if status 404 error code
                                                                SO_vals <- NA
                                                        }
                                                },
                                                error = function(e){ 
                                                        SO_vals <- NA
                                                })
                                        
                                }
                        #replace the NA value for shares outstanding with the web scraped value
                        BS_final_df$value <- ifelse(as.character(BS_final_df$tag_sec)=="Entity Common Stock Shares Outstanding" & is.na(as.character(BS_final_df$value)), SO_vals, as.character(BS_final_df$value))
                        print(paste("webscraped shares outstanding value for ticker-", all_tickers[i], ":", SO_vals, sep=""))
                        SO_vals <- NA
                        }
                }
        }
        
        #Do not append data if it does not meet following criteria
        if (max(as.character(BS_final_df$qtrs)) != "0"){
                next #any value in 'qtrs' variable should always equal to zero
        } else if (grepl("Q", as.character(BS_final_df$fq[1]))){
                temp_qtr <- sub("Q", "", as.character(BS_final_df$fq[1]))
                if (temp_qtr<=0 | temp_qtr>3){
                        next #the 'fq' should not be less than zero or greater than 3, if greater than 3, value should be 'FY'
                }
        } 
        
        #BS_final_df["line_item"][is.na(BS_df["line_item"])] <- "no" #replace NA values with 'no'
        BS_final_df2 <- rbind(BS_final_df2, BS_final_df)
        print(paste(paste("BS-", i, "-", count, sep=""), all_tickers[i], nrow(BS_final_df)))
        
        #this is used to speed up the loop. When 'count' variable equals 300, rbind BS_final_df2 to the final dataset
        if (count >= 300 & i != length(all_tickers)){
                BS_final_df3 <- rbind(BS_final_df3, BS_final_df2)
                BS_final_df2 <- data.frame()
                count <- 0
        } 
}

if (i == length(all_tickers)){ #if the 'count' variable is equal to the max iteration of the loop, and is less than 300, then rbind BS_final_df2
        # to the final dataset
        BS_final_df3 <- rbind(BS_final_df3, BS_final_df2)
}

#Remove any rows if there are duplicates found in the values of these four colums
BS_final_df3 <- BS_final_df3[!duplicated(BS_final_df3[c("ein_id", "tag_renamed", "value", "data_date")]),]
BS_final_df3 <- BS_final_df3[!is.na(BS_final_df3$value),]


#testing
#this one works on local file to get shares outstanding
# html2 <- readLines("C:\\Users\\james\\documents\\R2.htm")
# parsedHtml <- htmlParse(html2, asText = TRUE)
# vals <- xpathSApply(parsedHtml, "//tr[@class='ro']", xmlValue)
# vals2 <- xpathSApply(parsedHtml, "//tr[@class='re']", xmlValue)
# vals <- append(vals, vals2)
# vals <- vals[grepl("Entity Common Stock, Shares Outstanding", vals)]
# vals <- gsub("\\D+", "", vals) #removes all non-numeric digits in a string/vector of strings
# vals <- sum(as.numeric(vals))


