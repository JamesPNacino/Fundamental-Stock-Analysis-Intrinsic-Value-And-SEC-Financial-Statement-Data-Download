##### Script to create income statement data for companies ####
# Note: Must run Get_datav2.R script first 
#### Install packages if haven't already and load packages ####
#install.packages("readxl")
library(readxl)

#### Read in data that includes Balance Sheet tag names ####
#tag names are used for a more consistent naming convention for each balance sheet item
setwd("C:\\Users\\james\\OneDrive\\Documents\\Projects\\Financial_Analysis\\Data_Processing")
tags_df <- data.frame(read_excel("tag_conversion.xlsx")) #manually created excel sheet which includes common balance sheet items
names(tags_df)[names(tags_df) == "tag_SEC"] <- "tag"  #rename column to 'tag'

#### Tasks before looping to create income statement ####
cik_df <- cik_df[cik_df$form=="10-Q" | cik_df$form=="10-K",] #subset where the form is equal to 10-Q or 10-K
tick_loc_df <- loc_df[loc_df$stmt=="IS",] #subset to get only income statement report data
all_tickers <- unique(cik_df$instance) #get the unique tickers
IS_final_df2 <- data.frame() #temporary data frame, used to speed up the loop, data here will be appended to 'IS_final_df3'
IS_final_df3 <- data.frame() #the final income statement will be stored here
count <- 0 #used to track when to append IS_final_df2 to IS_final_df3

#### Loop through each ticker to get income statement data ####
for (i in 1:length(all_tickers)){ 
        count <- count + 1

        ticker_df <- cik_df[cik_df$instance==all_tickers[i],] #subset cik_df to get the cik number
        
        #numbers_df shows the financial numbers (values) and associated tags of the inputted ticker
        numbers_df <- fin_df[fin_df$adsh==as.character(ticker_df$adsh[1]),] #get the financial numbers where the unique adsh# is associated to your stock ticker
        if (nrow(numbers_df) == 0){
                next
        }
        
        #tick_loc_df shows the financial statement types and associated tags of the inputted ticker
        IS_tick_loc_df <- tick_loc_df[tick_loc_df$adsh==as.character(ticker_df$adsh[1]),] #get the financial statement type data where the unique adsh# is associated to your stock ticker
        if (nrow(IS_tick_loc_df) == 0){
                next
        }
        
        IS_tick_loc_df$url <- paste("https://www.sec.gov/Archives/edgar/data/", as.character(ticker_df$cik[1]), "/", gsub("-", "", as.character(ticker_df$adsh[1])), sep="")
        IS_tick_loc_df$form <- as.character(ticker_df$form[1]) #create a new column including whether data is 10-Q or 10-k
        IS_tick_loc_df$fy <- ticker_df$fy[1] #create new column to include fiscal year
        IS_tick_loc_df$fq <- ticker_df$fp[1] #create new column to include fiscal quarter
        
        report <- sort(unique(IS_tick_loc_df$report))[1] #there should only be one unique value
        IS_tick_loc_df <- IS_tick_loc_df[IS_tick_loc_df$report==report,]
        
        #numbers_df includes all the values of each of the associated tags
        IS_numbers_df <- merge(IS_tick_loc_df, numbers_df, by = "tag", all.x = TRUE) #merge the data together because we want the financial statement type, value, and tags

        #if all of the 'values' in the IS_numbers_df are NA, the statement would equal to TRUE and skip to next iteration
        if (length(sort(IS_numbers_df$value))==0){
                print(paste(all_tickers[i], "No numbers data.. skipped"))
                next
        }
        
        date <- sort(unique(IS_numbers_df$ddate), decreasing = TRUE)[1] #the latest quarter data is what we want
        IS_numbers_df <- IS_numbers_df[IS_numbers_df$ddate==date,]
        IS_numbers_df <- IS_numbers_df[!is.na(IS_numbers_df$tag),] #remove any tags that were missing after the merge
        
        #IS_numbers_df includes financial statement type, value, and associated tag data
        IS_tags_df <- tags_df[tags_df$financial_statement=="IS",] #selecting only income statement data
        IS_df <- merge(IS_numbers_df, IS_tags_df, by = "tag", all.x = TRUE) #merge data to get updated tags located on IS_tags_df
        IS_df$tag <- as.character(IS_df$tag)
        IS_df$tag <- gsub("([[:lower:]])([[:upper:]])", "\\1 \\2", IS_df$tag) #update original tag variable to include spaces between words
        IS_df$tag_renamed <- ifelse(is.na(IS_df$tag_renamed), IS_df$tag, IS_df$tag_renamed) #if the tag_renamed variable is not found ('NA'), then replace with original tag
        IS_df <- IS_df[order(IS_df$line, decreasing = FALSE),] #sort the data according to the correct order
        
        #Create the final Income Statement dataset with only specific columns that we need
        IS_final_df <- data.frame(cbind("tag_sec"=IS_df$tag, "label_sec"=as.character(IS_df$plabel), "report"=IS_df$report, "line"=IS_df$line, 
                                        "stmt"=as.character(IS_df$stmt), "data_date"=IS_df$ddate, "fy"=IS_df$fy,"fq"=as.character(IS_df$fq),
                                        "qtrs"=IS_df$qtrs, "uom"=as.character(IS_df$uom), 
                                        "tag_renamed"=IS_df$tag_renamed, "value"=IS_df$value, "line_item"=IS_df$line_item, "url"=IS_df$url, 
                                        "ein_id"=ticker_df$ein_id[1]))
        
        #Do not append data if it does not meet following criteria
        if (as.character(IS_final_df$fq[1]) == "FY" & max(as.character(IS_final_df$qtrs)) != "4"){
                next
        } else if (grepl("Q", as.character(IS_final_df$fq[1]))){ #if quarterly data, then have the 'qtrs' column match the 'fq' column
                temp_qtr <- sub("Q", "", as.character(IS_final_df$fq[1]))
                if (temp_qtr>3 | temp_qtr<=0){
                        next
                }
                IS_final_df <- IS_final_df[IS_final_df$qtrs == temp_qtr | IS_final_df$qtrs=="1",]
                if (nrow(IS_final_df) == 0){
                        next
                }
        }
        
        
        #IS_final_df["line_item"][is.na(IS_df["line_item"])] <- "no" #replace NA values with 'no'
        IS_final_df2 <- rbind(IS_final_df2, IS_final_df)
        print(paste(paste("IS-", i, "-", count, sep=""), all_tickers[i], nrow(IS_final_df), IS_final_df$fq[1], max(as.character(IS_final_df$qtrs))))
        
        #this is used to speed up the loop. When 'count' variable equals 300, rbind IS_final_df2 to the final dataset
        if (count >= 300 & i != length(all_tickers)){
                IS_final_df3 <- rbind(IS_final_df3, IS_final_df2)
                IS_final_df2 <- data.frame()
                count <- 0
        } 
}
if (i == length(all_tickers)){ #if the 'count' variable is equal to the max iteration of the loop, and is less than 300, then rbind IS_final_df2
        # to the final dataset
        IS_final_df3 <- rbind(IS_final_df3, IS_final_df2)
}

#Remove any rows if there are duplicates found in the values of these four colums
IS_final_df3 <- IS_final_df3[!duplicated(IS_final_df3[c("ein_id", "tag_renamed", "value", "data_date")]),]
IS_final_df3 <- IS_final_df3[!is.na(IS_final_df3$value),]