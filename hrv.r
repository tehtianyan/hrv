#load and analyse emwave.emdb data
#sqlite emdb file is composed of 3 tables: Client PrimaryData VersionTable
# 60*1000/LiveIBI gives BPM

#TODO
#convert all lists to numeric
#plot "The Zone" lines
#bioconduction PROcess peaks function
#split screen to get "banking" (45 degrees in curves)
#export function for Kubios
#fix final score (currently reading only 1 byte)

#longest singular duration spent in high coherence
#power spectrum VLF LF HF histogram IBI/60 Hz
#frequency band VLF 0-0.04 Hz, LF 0.04 - 0.15 Hz, HF 0.15 0.5 Hz
library(RSQLite)

#sqlite db location is system dependent
user <- Sys.info()['user']
if( Sys.info()['sysname'] == "Windows") {
	emdb <- paste('C:/Documents and Settings/',user,'/My\ Documents/emWave/emwave.emdb',sep="")
} else {
    #assumed the linux OS has the same username
	emdb <- paste('/windows/D/Documents\ and\ Settings/',user,'/My\ Documents/emWave/emwave.emdb',sep="")
}

#if emwave directory cannot be found then assume we have a copy of the db in the working directory
if(!file.exists(emdb)) {
  cat(emdb,'\n')
	emdb <- 'emwave.emdb'
}
############# CONNECT & LOAD
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname=emdb)

dbListTables(con)
#sessions may not be stored in chronological order as sessions can be carried out and uploaded only at a later time
rs <- dbSendQuery(con, "select * from PrimaryData order by IBIStartTime")
h <- fetch(rs, n=-1)
dbClearResult(rs)
 
dbDisconnect(con)
#############

#final scores
#as.numeric(unlist(h$AccumZoneScore[1])[length(unlist(h$AccumZoneScore[1]))-3])
#won't work if value > 255, must have hex values in group of 4
h$FinalScore <- sapply( h$AccumZoneScore, FUN = function(x) as.numeric(unlist(x)[length(unlist(x))-3]) )
h$PctLow <- 100 - h$PctMedium - h$PctHigh
#lappy readBin(unlist(h$AccumZoneScore[10]),"int",size=4,endian="little",n=length(unlist(h$AccumZoneScore[10]))/4)

#pulse <- 60*1000/readBin(unlist(h$LiveIBI[1]),"int",size=4,endian="little",n=length(unlist(h$LiveIBI[1]))/4)
#pulset <- cumsum(readBin(unlist(h$LiveIBI[1]),"int",size=4,endian="little",n=length(unlist(h$LiveIBI[1]))/4))
#plot(pulse ~ pulset,type ="l")

h$date <- as.POSIXct(h$IBIStartTime,origin="1970-01-01")
h$end  <- as.POSIXct(h$IBIEndTime,origin="1970-01-01")
h$sessiontime <- h$IBIEndTime - h$IBIStartTime
h$ChallengeLevel <- factor(h$ChallengeLevel,levels=c(1,2,3,4),labels=c("Low","Medium","High","Highest"))
h$Endian <- factor(h$Endian,levels=c(0,1),labels=c("big","little"))

hrvplot <- function(n=1) {
pulse <- 60*1000/readBin(unlist(h$LiveIBI[n]),"int",size=4,endian=h$Endian,n=length(unlist(h$LiveIBI[n]))/4)
pulset <- cumsum(readBin(unlist(h$LiveIBI[n]),"int",size=4,endian=h$Endian,n=length(unlist(h$LiveIBI[n]))/4))
score <- readBin(unlist(h$AccumZoneScore[n]),"int",size=4,endian=h$Endian,n=length(unlist(h$AccumZoneScore[n]))/4)
s <- ts(score)

par(mfrow=c(2,1),mai=c(0.4,0.4,0.2,0.2),lab=c(10,10,7))
plot(pulse ~ pulset,xlab="time",ylab="mean Heart Rate (BPM)",type ="l")
plot(s,xlab="time",ylab="Accumulated Coherence Score",type ="l")

#LEGEND
cat('Start',strftime(h$date[n],format="%x %X"),'\n')
cat('End  ',strftime(h$end[n],format="%x %X"),'\n')
cat('session time',as.integer(h$sessiontime[n]/60),'min',h$sessiontime[n] %% 60,'sec','\n')
cat('mean HR:',mean(pulse),'bpm\n')
cat('final score',h$FinalScore[n],'\n')
cat('level',h$ChallengeLevel[n],'\n')
cat('Coherence Ratio Low/Med/High %',h$PctLow[n],h$PctMedium[n],h$PctHigh[n],'\n')
}

#start by displaying summary of all sessions
par(mfrow=c(3,1),mai=c(0.4,0.7,0.2,0.2),lab=c(10,10,7))
barplot(t(cbind(h$PctLow,h$PctMedium,h$PctHigh))
        ,col=c('red','blue','green')
        ,xlab=as.numeric(h$ChallengeLevel)
        ,ylab="%"
        ,main="coherence ratio by session"
	    ,legend=c('Low','Medium','High')
        ,args.legend = list(x = "topleft")
       )
#levels
plot(ts(h$ChallengeLevel),ylab="Challenge Level",xlab="session",main="level by session")
#scores
plot(ts(h$FinalScore),ylab="Accumulated Score",main="final accumulated score by session")

#plot(h$PctHigh ~ h$date,type="l",col="green")
#lines(h$PctMedium ~ h$date,type="l",col="blue")
