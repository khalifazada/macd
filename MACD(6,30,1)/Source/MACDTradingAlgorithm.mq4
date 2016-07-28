//+------------------------------------------------------------------+
//|                                         MACDTradingAlgorithm.mq4 |
//|                                              Chingiz Khalifazada |
//|                                          c.khalifazada@gmail.com |
//+------------------------------------------------------------------+

/*
Strategy Philosophy:
Determine long term stdev and use it as a unitary distance value throughout the strategy. 
*/

#property copyright "Chingiz Khalifazada"
#property link      "c.khalifazada@gmail.com"
#property version   "1.00"
#property strict

//--- input parameters
input int const   N=7;                    //Maximum safety level
input int const   macdThreshold=2000;     //Threshold from 0 line. SL Distance
input int const   macdFastEMA=6;          //1 Day (timeframe dependent)
input int const   macdSlowEMA=30;         //1 Week (timeframe dependent)
input int const   stDevMult=2;            //Distance multiplier for TP

//--- variables
   datetime previous_time;
   color    direction;
   int      ticket;
   int      orderBook[];


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- On the first tick of a new bar detect shape, direction & open trades.   
   if(firstTick() && shapeDetected() && !activeTrades()) //There are no active trades, peak/trough detected
     {                                                   //and this is the first tick of a new bar.
      int sum = (int)MathPow(2,(N+1))-(N+2); //Determine total number of units based on safety level N.
      //Print(IntegerToString(sum));
      double lots = NormalizeDouble(AccountBalance()/(sum*macdThreshold),2); //Based on account size, determine lot per unit.
      //Print("LOTS: " + DoubleToStr(lots,2));
      if(lots<0.01) //Either N is too big or account has a small balance.
        {
         Print("INVALID LOTS AMOUNT. CANNOT TRADE.");
        }
      else
        {
         if(direction==clrGreen) //Determine direction and open orders
           {
            orderOpen(OP_BUY,OP_BUYLIMIT,Ask,lots,1); //Open 1 BUY market order, N-1 BUYLIMIT pending orders,
           }                                          //at current Ask price, unitary lot size, positive sign direction.
         else
            orderOpen(OP_SELL,OP_SELLLIMIT,Bid,lots,-1);
        }
     }
//---
  }
//+------------------------------------------------------------------+
//| First Tick of a New Bar                                          |
//+------------------------------------------------------------------+
bool firstTick()
{
   bool value=FALSE;
   datetime current_time = iTime(NULL,NULL,0);

   if (previous_time!=current_time)
   {
      previous_time=current_time;
      value=true;
   } 

   return(value);
}

//+------------------------------------------------------------------+
//| MACD above/below Threshold                                       |
//+------------------------------------------------------------------+
bool shapeDetected()
   {
//---
   bool tradeDecision = FALSE; //Orders will be placed only if decision to trade becomes true.
   double t1, t2, t3; //Create points to detect hill/trough shape
//---
   t1 = iMACD(NULL,0,macdFastEMA,macdSlowEMA,1,0,0,1); //MACD reading on previous bar.
   t2 = iMACD(NULL,0,macdFastEMA,macdSlowEMA,1,0,0,2); //MACD reading 2 bars ago.
   t3 = iMACD(NULL,0,macdFastEMA,macdSlowEMA,1,0,0,3);
//---
   if(t2>t1 && t2>=t3 && t2>(macdThreshold*Point)) //If middle point is above the other & above some threshold point
     {
      tradeDecision = TRUE; //Decided to trade
      direction = clrRed; //Direction to trade is SELL
     }
   if(t2<t1 && t2<=t3 && t2<(macdThreshold*Point*(-1))) //If trough
     {
      tradeDecision = TRUE;
      direction = clrGreen;
     }     
//---
   return(tradeDecision);
   }
//+------------------------------------------------------------------+
//| Check for active trades                                          |
//+------------------------------------------------------------------+
//If any order from the current order book was closed by TP,
//delete all other pending orders and reset the book.
bool activeTrades()
   {
//---   
   bool activeTrades = TRUE;  //Assume there are active open and pending orders
//---
   if(OrdersTotal()!=0) //If their total number is not 0
     {
         for(int i=0;i<N;i++) //Search through the order book
         {
            bool orderSelect = OrderSelect(orderBook[i],SELECT_BY_TICKET); //by selecting each order
            if(orderSelect && OrderClosePrice()==OrderTakeProfit()) //If successfull & closed by TP
            { 
               Print("ORDER "+IntegerToString(orderBook[i])+" CLOSED BY TP");
               activeTrades = FALSE; //Delete all remaining orders.
               for(int j=i+1;j<N;j++) //TRY: All js must be higher than current i.
               {
                   bool orderDeleted = OrderDelete(orderBook[j]); //Delete each order by ticket #
                   if(orderDeleted)
                     Print("ORDER "+IntegerToString(orderBook[j])+" DELETED. jth position is: "+IntegerToString(j));
               }
            }
         }
     }
     else //Total number of open & pending orders is 0. No active trades.
        {
         activeTrades = FALSE;
         Print("NO ACTIVE TRADES");
        }
   return(activeTrades);
   }
//+------------------------------------------------------------------+
//| Order opener                                                     |
//+------------------------------------------------------------------+
void orderOpen(int orderType1,
               int orderType2,
               double price,
               double lots,
               int sign)
   {
//---
   int newN = ArrayResize(orderBook,N); //Resize order book
//---
/*
   if(newN==N)
     {
      Print("ORDER BOOK RESIZED TO: "+IntegerToString(newN));
     }
   else
     {
      Print("ORDER BOOK COULD NOT BE RESIZED");
     }
*/   
//---
   orderBook[0]=OrderSend(Symbol(), //Generate market order
                        orderType1,
                        lots,
                        price, //Opening Price
                        0,
                        price-macdThreshold*Point*sign, //Stop Loss
                        price+stDevMult*macdThreshold*Point*sign, //Take Profit
                        NULL,
                        0,
                        0,
                        clrNONE);
//---
   if(orderBook[0]!=-1)
      Print("BUY ORDER OPENED #",IntegerToString(orderBook[0]));
   else
      Print("BUY ORDER NOT OPENED #",GetLastError());            
//---
   for(int i=2;i<=N;i++) //Open remaining N-1 pending orders
     {
      int lotMult = (int)MathRound(MathPow(2,i))-1;
      orderBook[i-1]=OrderSend(Symbol(),
                           orderType2,
                           lots*lotMult,
                           price-macdThreshold*Point*sign*(i-1),                                   //Opening Price
                           0,
                           price-macdThreshold*Point*sign*i,                                       //Stop Loss
                           price-macdThreshold*Point*sign*(i-1)+stDevMult*macdThreshold*Point*sign,   //Take Profit
                           NULL,
                           0,
                           0,
                           clrGray);
      Print("i: "+IntegerToString(i)+" lotMult:"+IntegerToString(lotMult));
     }
   }
   
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
