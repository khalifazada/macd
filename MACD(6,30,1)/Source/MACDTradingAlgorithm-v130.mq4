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
#property version   "1.30"
#property strict

//--- input parameters
input int const   N=8;                    //Maximum safety level
input int const   macdThreshold=1000;     //Threshold from 0 line
input int const   macdFastEMA=6;          //1 Day (timeframe dependent)
input int const   macdSlowEMA=30;         //1 Week (timeframe dependent)
input int const   stDevMult=2;            //Distance multiplier for TP
input int const   stDevDist=1300;         //SL & TP level

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
   if(firstTick() && shapeDetected() && OrdersTotal()==0)                     //If there are no active order, peak/trough has been detected
     {                                                                        //and this is the first tick of a new bar.
      int sum = (int)MathPow(2,(N+1))-(N+2);                                  //Determine total number of units based on safety level N.
      double lots = NormalizeDouble(AccountBalance()/(sum*macdThreshold),2);  //Based on account size, determine lot per unit.
      if(lots<0.01)                                                           //Either N is too big or account has a small balance.
        {
         Print("INVALID LOTS AMOUNT. CANNOT TRADE.");
        }
      else
        {
         if(direction==clrGreen)                                              //Determine direction
            orderOpen(OP_BUY,OP_BUYLIMIT,Ask,lots,1);                         //Open 1 BUY market order, N-1 BUYLIMIT pending orders,
         else                                                                 //At current Ask price, unitary lot size, positive sign direction.
            orderOpen(OP_SELL,OP_SELLLIMIT,Bid,lots,-1);
        }
     }
   else
     {
      if(OrdersTotal()!=0)                                                    //If there are active orders
        {
         for(int i=0;i<ArraySize(orderBook);i++)                              //Select each order & check if closed by TP
           {
            if(OrderSelect(orderBook[i],SELECT_BY_TICKET)==TRUE && OrderTakeProfit()==OrderClosePrice())
              {
               Print(IntegerToString(i)+"th order closed by TP");
               for(int j=i+1;j<ArraySize(orderBook);j++)                      //If so, delete remaining pending orders
                  {
                   bool orderDeleted = OrderDelete(orderBook[j]);
                   if(orderDeleted==TRUE)
                     {
                      Print(IntegerToString(j)+"th order deleted");
                     }
                   else
                     {
                      Print(IntegerToString(j)+"th order not deleted. Error #:"+IntegerToString(GetLastError()));
                     }
                  }
               break;                                                         //Break out of the 1st loop when all orders are deleted
              }
           }
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
   orderBook[0]=OrderSend(Symbol(), //Generate market order
                        orderType1,
                        lots,
                        price, //Opening Price
                        0,
                        price-stDevDist*Point*sign, //Stop Loss
                        price+stDevMult*stDevDist*Point*sign, //Take Profit
                        NULL,
                        0,
                        0,
                        clrNONE);
   if(orderBook[0]!=-1)
      Print("MARKET ORDER OPENED");
   else
      Print("MARKET ORDER NOT OPENED. ERROR #:",GetLastError());            
   for(int i=2;i<=N;i++) //Open remaining N-1 pending orders
     {
      int lotMult = (int)MathRound(MathPow(2,i))-1;
      orderBook[i-1]=OrderSend(Symbol(),
                           orderType2,
                           lots*lotMult,
                           price-stDevDist*Point*sign*(i-1), //Opening Price
                           0,
                           price-stDevDist*Point*sign*i, //Stop Loss
                           price-stDevDist*Point*sign*(i-1)+stDevMult*stDevDist*Point*sign, //Take Profit
                           NULL,
                           0,
                           0,
                           clrGray);
      //Print("i: "+IntegerToString(i)+" lotMult:"+IntegerToString(lotMult));
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
