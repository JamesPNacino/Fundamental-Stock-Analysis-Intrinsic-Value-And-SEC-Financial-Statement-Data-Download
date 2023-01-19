#### Final cleaning of the data ####
library(data.table)
#this dataset has all the combined formatted data of all the previous data periods combined into one file
two_years_past <- as.numeric(sub("Q[1-4]", "", Data_year)) - 2
combined_df <- data.frame(dbGetQuery(con, paste("SELECT * FROM financial WHERE fy>=", two_years_past, sep="")))
last_id <- max(as.numeric(as.character(combined_df$record_id))) 
combined_df <- combined_df[combined_df$qtrs!="0",] #filter out unnecessary data as it will take the loop much longer the more data
combined_df <- combined_df[combined_df$qtrs!="4",]


#Clean the 'fq' and 'qtrs' column
all_tickers <- as.character(unique(final_df$ein_id))
#all_tickers <- "942404110" #msft test
final2_df <- data.frame() #this is a temporary df
final3_df <- data.frame() #this will be the final dataset
temp2_df <- data.frame() #this will include the fiscal year end data
count <- 0
for (i in 1:length(all_tickers)){
#for (i in 1:1){
        count <- count + 1
        temp_df <- final_df[which(final_df$ein_id == as.character(all_tickers[i])),] #which() is just a faster way to subset
        temp_df <- temp_df[which(!is.na(temp_df$tag_sec)),]
        IS_df <- temp_df[which(temp_df$stmt == "IS"),]
        CF_df <- temp_df[which(temp_df$stmt == "CF"),]
        quarter <- max(as.character(temp_df$qtrs))
        if (temp_df$fq[1] == "Q1" | temp_df$fq[1] == "Q2" | temp_df$fq[1] == "Q3" | temp_df$fq[1] == "FY"){
        } else { next }#the fiscal quarter should equal one of the values
        
        if (temp_df$fq[1]!="FY" & sub("Q", "", as.character(temp_df$fq[1])) != quarter & quarter != 0){
                next} #the 'fq' should match 'qtrs' when 'fq' is not "FY" value and 'qtrs' does not equal zero
        
        if (nrow(IS_df) != 0){
                IS_quarter <- max(as.character(IS_df$qtrs))
        } else {
                IS_quarter <- NA
        }
        if (nrow(CF_df) != 0){
                CF_quarter <- max(as.character(CF_df$qtrs))
        } else {
                CF_quarter <- NA
        }
        
        if (quarter > 4){ #sometimes the data is weird and has a quarter greater than 4, so skip these tickers
                next
        }
        if (!is.na(IS_quarter) & !is.na(CF_quarter)){
                if ((IS_quarter != CF_quarter) & CF_quarter!="0"){ #these max values should match and if the max value of CF is not zero then skip
                        next
                }
        }
        
        if (quarter == 4 & temp_df$fq[1] != "FY"){
                next
        }
        #if quarter is equal to 'FY', then copy data and change quarter of copied data to "Q4"
        if ((quarter == 4 & temp_df$fq[1] == "FY") | (quarter == 0 & temp_df$fq[1] == "FY" & is.na(IS_quarter))){ #second condition is if it is 'FY' and we only have BS or CF ending balance data
                temp2_df <- temp_df
                temp2_df$fq <- "FY"
                temp2_df <- temp2_df[which(temp2_df$qtrs == "0" | temp2_df$qtrs == "4"),] #only get FY end data.. when it's FY end for a company, CF qtrs would equal 4; BS qtrs would equal 0; IS qtrs would have qtrs that equal 1 and 4, but only want 4
                temp2_df$qtrs <- ifelse(as.character(temp2_df$fq)=="FY", 4, as.character(temp2_df$qtrs))
                
                #instead of quarter equal to 'FY' change to 'Q4' because still need Q4 quarterly data, not just FY end
                temp_df$fq <- "Q4"
        } 
        #balance sheet data is already formatted correct. But if see income statment and cash flow statements where 'qtrs' = 1, then 
        #change value to zero. Zero will be the correct data for that quarter. For example if the quarter has a value of two, that means
        #it aggregated both the first and second quarters' data
        temp_df$qtrs <- ifelse(as.character(temp_df$stmt)=="IS" & as.character(temp_df$qtrs)=="1", 0, as.character(temp_df$qtrs))
        
        #temp_df$match <- ifelse(as.character(temp_df$stmt)=="IS" & (temp_df$tag_sec=="Earnings Per Share Basic" | temp_df$tag_sec=="Earnings Per Share Diluted" |
         #                                                                   temp_df$tag_sec=="Weighted Average Number Of Shares Outstanding Basic" | temp_df$tag_sec=="Weighted Average Number Of Diluted Shares Outstanding" | 
          #                                                                  temp_df$tag_sec=="Common Stock Dividends Per Share Declared"), "match", "no match")
        #temp_df <- temp_df[order(as.character(temp_df$stmt), as.character(temp_df$label_sec), as.character(temp_df$qtrs)),]
        #temp_df <- temp_df[!duplicated(temp_df[c("tag_sec", "label_sec", "stmt", "match")]),]
        #temp_df$match <- NULL
        #EPS and the following tags, should not be aggregated. Meaning Q3 data for EPS should not be subtracted from Q2 data. This is why eps_add_df, we are getting the subset, where qtrs=0 only. 
        #But will later add that that data after filtering the aggregated EPS (and other tags out)
        #eps_add_df <- temp_df[which(temp_df$qtrs=="0" & (temp_df$tag_sec=="Earnings Per Share Basic" | temp_df$tag_sec=="Earnings Per Share Diluted" |
                                                       #    temp_df$tag_sec=="Weighted Average Number Of Shares Outstanding Basic" | temp_df$tag_sec=="Weighted Average Number Of Diluted Shares Outstanding" | 
                                                        #   temp_df$tag_sec=="Common Stock Dividends Per Share Declared")),]
        #temp_df <- temp_df[which(temp_df$tag_sec!="Earnings Per Share Basic" & temp_df$tag_sec!="Earnings Per Share Diluted" &
                                                         # temp_df$tag_sec!="Weighted Average Number Of Shares Outstanding Basic" & temp_df$tag_sec!="Weighted Average Number Of Diluted Shares Outstanding" & 
                                                         # temp_df$tag_sec!="Common Stock Dividends Per Share Declared"),]
        #temp_df <- rbind(temp_df, eps_add_df)
        
        #temp_df <- temp_df[order(as.character(temp_df$stmt), as.character(temp_df$label_sec), as.character(temp_df$qtrs)),]
        #temp_df <- temp_df[!duplicated(temp_df[c("tag_sec", "label_sec", "stmt")]),] #when finds a duplice, it will delete second duplicate row which is why sorted first
        temp_df <- temp_df[order(as.character(temp_df$stmt), as.character(temp_df$line)),]
        
        print(paste(temp_df$fq[1], "[max qtr:", quarter,"]", i, count))
        
        if (nrow(temp2_df)!=0){ #if there is Q4 or FY end data
                final2_df <- rbind(final2_df, temp_df, temp2_df)
                temp2_df <- data.frame()
        } else {
                final2_df <- rbind(final2_df, temp_df)
        }
        if (count >= 100 & i != length(all_tickers)){ #used to speed up for loop
                final3_df <- rbind(final3_df, final2_df)
                final2_df <- data.frame()
                count <- 0
        }
}
if (i == length(all_tickers)){ #append the remaining data to final3_df
        # to the final dataset
        final3_df <- rbind(final3_df, final2_df)
}


##code below needs to be tested
#this is the final loop to get quarterly data. Quarterly data is already calculated on the balance sheet. Howerver quarterly data is not calculated
#automatically on the income statement when it is 'fq' == 'FY', or for the cash flow statement where 'fq' == '2 or 3 or 4'
all_tickers <- as.character(unique(final3_df$ein_id))
#all_tickers <- "911144442"
temp_df <- data.frame()
count <- 0
for (i in 1:length(all_tickers)){
        count <- count + 1
        
        print(paste(all_tickers[i], i, sep="-"))  #keep track of where in the loop it is
        get_df <- final3_df[final3_df$ein_id==all_tickers[i],]
        
        if (get_df$fq[1] == "Q1"){ #skip the iteration because if the data is Q1, then all the data is correct and not aggregated
                print(paste("Q1", paste(i, count, all_tickers[i], sep="-")))
                next
        }
        
        #if Q2 data, then filter combined_df to get the previous quarter data (Q1 data) so you can subtract
        if (get_df$fq[1] == "Q2"){
                test_df <- combined_df[combined_df$fy == as.character(get_df$fy[1]) & combined_df$fy == as.character(get_df$fy[1]) & combined_df$fq == "Q1"
                                      & combined_df$ein_id==as.character(get_df$ein_id[1]),]
                if (nrow(test_df)==0){ #if there is no Q1 quarter data available
                        next
                }
                for (x in 1:nrow(get_df)){ #go through each row of the ticker's dataset and subtract from the previous quarter's ticker data
                        if (get_df$stmt[x] == "CF" & get_df$fq[x] == "Q2" & get_df$qtrs[x]!="0"){
                                
                                test2_df <- test_df[as.character(test_df$tag_sec)==as.character(get_df$tag_sec[x]) & as.character(test_df$tag_renamed)==as.character(get_df$tag_renamed[x]) 
                                                    & as.character(test_df$stmt)=="CF" & as.character(test_df$qtrs)!="0",]
                                if (nrow(test2_df) == 0 | nrow(test2_df)>1){ #if there are more than one row, then skip
                                        next
                                }
                                get_df$value <- as.character(get_df$value)
                                get_df$qtrs <- as.character(get_df$qtrs)
                                get_df$value[x] <- as.numeric(get_df$value[x]) - as.numeric(test2_df$value[1])
                                print(paste(get_df$value[x], "CF-Q2", paste(i, count, all_tickers[i], sep="-")))
                                get_df$qtrs[x] <- "0"
                                
                        }
                }
        }
        if (get_df$fq[1] == "Q3"){ 
                test_df <- combined_df[combined_df$fy == as.character(get_df$fy[1]) & combined_df$fy == as.character(get_df$fy[1]) & combined_df$fq == "Q2"
                                       & combined_df$ein_id==as.character(get_df$ein_id[1]),]
                if (nrow(test_df)==0){
                        next
                }
                for (x in 1:nrow(get_df)){
                        if (get_df$stmt[x] == "CF" & get_df$fq[x] == "Q3" & get_df$qtrs[x]!="0"){
                                
                                test2_df <- test_df[as.character(test_df$tag_sec)==as.character(get_df$tag_sec[x]) & as.character(test_df$tag_renamed)==as.character(get_df$tag_renamed[x]) 
                                                    & as.character(test_df$stmt)=="CF" & as.character(test_df$qtrs)!="0",]
                                if (nrow(test2_df) == 0 | nrow(test2_df)>1){
                                        next
                                }
                                get_df$value <- as.character(get_df$value)
                                get_df$qtrs <- as.character(get_df$qtrs)
                                get_df$value[x] <- as.numeric(get_df$value[x]) - as.numeric(test2_df$value[1])
                                print(paste(get_df$value[x], "CF-Q3", paste(i, count, all_tickers[i], sep="-")))
                                get_df$qtrs[x] <- "0"
                                
                        }
                }
        }
        if (get_df$fq[1] == "Q4"){ 
                test_df <- combined_df[combined_df$fy == as.character(get_df$fy[1]) & combined_df$fy == as.character(get_df$fy[1]) & combined_df$fq == "Q3"
                                       & combined_df$ein_id==as.character(get_df$ein_id[1]),]
                if (nrow(test_df)==0){
                        next
                }
                for (x in 1:nrow(get_df)){
                        if (get_df$stmt[x] == "IS" & get_df$fq[x] == "Q4" & get_df$qtrs[x]!="0"){
                                #These weighted average values should not be subtracted from previous quarter, so skip to next iteration
                                if (get_df$tag_sec[x]=="Weighted Average Number Of Shares Outstanding Basic" | get_df$tag_sec[x]=="Weighted Average Number Of Diluted Shares Outstanding"){
                                        next
                                }
                                
                                #for EPS basic/diluted (most of time) (and other tag's values (depends on each stock)), it is already calculated for Q4 only data, then skip to next iteration. But, if it isn't and only has aggregated Q4 data, subtract from Q3 eps data  
                                value <- as.character(get_df$tag_sec[x])
                                value_2 <- as.character(get_df$tag_renamed[x])
                                val_df <- get_df[get_df$fq == "Q4" & (get_df$tag_sec==value) & (get_df$tag_renamed==value_2),]
                                min_qtr <- min(as.character(val_df$qtrs))
                                # skip to next iteration if EPS (or other value) has already been calculated for Q4 only data. 
                                if (min_qtr == "0"){next}

                                test2_df <- test_df[as.character(test_df$tag_sec)==as.character(get_df$tag_sec[x]) & as.character(test_df$tag_renamed)==as.character(get_df$tag_renamed[x]) 
                                                    & as.character(test_df$stmt)=="IS" & as.character(test_df$qtrs)=="3",]
                                if (nrow(test2_df) == 0 | nrow(test2_df)>1){
                                        next
                                }
                                get_df$value <- as.character(get_df$value)
                                get_df$qtrs <- as.character(get_df$qtrs)
                                get_df$value[x] <- as.numeric(get_df$value[x]) - as.numeric(test2_df$value[1])
                                print(paste(get_df$value[x], "IS-Q4", paste(i, count, all_tickers[i], sep="-")))
                                get_df$qtrs[x] <- "0"
                        
                        }
                        
                        if (get_df$stmt[x] == "CF" & get_df$fq[x] == "Q4" & get_df$qtrs[x]!="0"){
                                
                                test2_df <- test_df[as.character(test_df$tag_sec)==as.character(get_df$tag_sec[x]) & as.character(test_df$tag_renamed)==as.character(get_df$tag_renamed[x]) 
                                                    & as.character(test_df$stmt)=="CF" & as.character(test_df$qtrs)!="0",]
                                if (nrow(test2_df) == 0 | nrow(test2_df)>1){
                                        next
                                }
                                get_df$value <- as.character(get_df$value)
                                get_df$qtrs <- as.character(get_df$qtrs)
                                get_df$value[x] <- as.numeric(get_df$value[x]) - as.numeric(test2_df$value[1])
                                print(paste(get_df$value[x], "CF-Q4", paste(i, count, all_tickers[i], sep="-")))
                                get_df$qtrs[x] <- "0"
                                
                        }
                }
        }
        temp_df <- rbind(temp_df, get_df)
        if (count >= 100 & i != length(all_tickers)){
                final3_df <- rbind(final3_df, temp_df)
                temp_df <- data.frame()
                count <- 0
        }
}
if (i == length(all_tickers)){
        final3_df <- rbind(final3_df, temp_df)
}


#this is the final dataset
final3_df <- final3_df[!duplicated(final3_df[c("stmt", "ein_id", "tag_sec", "tag_renamed", "fy", "fq", "qtrs", "value")]),] #remove duplicates
final3_df$tag_sec <- sub("^ {1,100}", "", final3_df$tag_sec) #remove any white space in the beginning
final3_df$label_sec <- sub("^ {1,100}", "", final3_df$label_sec) #remove any white space in the beginning
final3_df$tag_renamed <- sub("^ {1,100}", "", final3_df$tag_renamed) #remove any white space in the beginning
temp_df <- final3_df[final3_df$stmt=="CF" & final3_df$fq=="Q1" & final3_df$qtrs=="1",] #will append final3_df data where CF quarter equals 1, change to 0
if (nrow(temp_df) >= 1){
        temp_df$qtrs <- "0"
}
final3_df <- rbind(final3_df, temp_df)
final3_df <- final3_df[order(as.character(final3_df$ein_id), as.character(final3_df$stmt), as.character(final3_df$fq), as.character(final3_df$line), decreasing = FALSE),] #sort by ein_id
final3_df$record_id <- seq.int(nrow(final3_df)) #create an id column incrementing by one. e.g. row 1 has value 1, row 2 has value 2
final3_df$record_id <- final3_df$record_id + last_id
