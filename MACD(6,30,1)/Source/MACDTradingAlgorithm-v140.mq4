//+------------------------------------------------------------------+
//|                                         MACDTradingAlgorithm.mq4 |
//|                                              Chingiz Khalifazada |
//|                                          c.khalifazada@gmail.com |
//+------------------------------------------------------------------+

/*
Strategy Philosophy:
Place orders at MACD extremums above a given threshold.
Bet on probability of price retracing a particular distance from these points.
NOTE: See illustration for further detail.
*/

#property copyright "Chingiz Khalifazada"
#property link      "c.khalifazada@gmail.com"
#property version   "1.40"
#property strict

//--- input parameters
input int      const   N               =  10;        //Maximum safety level
input int      const   macdThreshold   =  250;       //Threshold from 0 line
input int      const   macdFastEMA     =  6;         //MACD Fast MA
input int      const   macdSlowEMA     =  30;        //MACD Slow MA
input double   const   multTP          =  1.35;      //Multiplier for TP distance
input int      const   orderDistance   =  360;       //Distance between orders

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
   int activeOrders = OrdersTotal();
   if(activeOrders==0)
     {
      if(firstTick())
        {
         if(shapeDetected())
           {
            int units = (int)MathPow(2,(N+1))-(N+2);                                //Determine total number of units based on safety level N.
            double unitValue = AccountBalance()/units;
            double lots = unitValue/orderDistance;
            lots = NormalizeDouble(lots,2);                                         //Based on account size, determine lot per unit.
            if(lots<0.01)                                                           //Either N is too big or account has a small balance.
              {
               Print(lots,"<0.01 INVALID LOTS. CANNOT TRADE");
              }
            else
              {
               RefreshRates();
               if(direction==clrGreen)                                              //Determine direction
                  orderOpen(OP_BUY,OP_BUYLIMIT,Ask,lots,1);                         //Open 1 BUY market order, N-1 BUYLIMIT pending orders,
               else                                                                 //At current Ask price, unitary lot size, positive sign direction.
                  orderOpen(OP_SELL,OP_SELLLIMIT,Bid,lots,-1);
              }
           }
        }
     }
   else
     {
      //Active orders found
      for(int i=0;i<N;i++)
        {
         RefreshRates();
         if(OrderSelect(orderBook[i],SELECT_BY_TICKET))                             //Select each order by ticket #
           {
            if(OrderCloseTime()!=0 && OrderClosePrice()==OrderTakeProfit())         //Check if order closed by TP
              {
               Print(i,"TH ORDER CLOSED AT TP. CL:",OrderClosePrice(),", TP:",OrderTakeProfit());
               for(int j=i;j<N;j++)                                                 //If so, delete remaining pending orders
                 {
                  if(OrderDelete(orderBook[j]))                                     //If order hasn't closed yet then delete it
                    {
                     Print(j+1,"TH ORDER DELETED");
                    }
                  else
                    {
                     Print(j+1,"TH ORDER NOT DELETED");
                    }
                 }
               break;                                                               //Finish checking, all orders deleted
              }
           }
        }
     }
//---
  }

//+------------------------------------------------------------------+
//| Order opener                                                     |
//+------------------------------------------------------------------+
void orderOpen(int orderType1,int orderType2,double price,double lots,int sign)
  {
   Print("PLACING ORDERS");
   ArrayResize(orderBook,N);                                            //Resize order book
   orderBook[0]=OrderSend(Symbol(),                                     //Generate market order
                        orderType1,
                        lots,
                        price,                                          //Opening Price
                        0,
                        price-orderDistance*Point*sign,                 //Stop Loss
                        price+multTP*orderDistance*Point*sign,          //Take Profit
                        NULL,
                        0,
                        0,
                        clrNONE);
   if(orderBook[0]!=-1)
      Print("MARKET ORDER OPENED");
   else
      Print("MARKET ORDER NOT OPENED. ERROR # ",GetLastError());            
   
   //Open remaining N-1 pending orders
   for(int i=2;i<=N;i++)
     {
      RefreshRates();

      int      lotMult     = (int)MathRound(MathPow(2,i))-1;
      double   spread      = NormalizeDouble(Ask-Bid,Digits);
      double   openPrice   = NormalizeDouble(price-orderDistance*Point*sign*(i-1)+spread*sign,Digits); //change 0.00020 to variable spread
      double   stopLoss    = NormalizeDouble(price-orderDistance*Point*sign*i,Digits);
      double   takeProfit  = NormalizeDouble(price-orderDistance*Point*sign*(i-1)+multTP*orderDistance*Point*sign,Digits);
      
      Print("lotMult:",lotMult," spread:",spread," openPrice:",openPrice," stopLoss:",stopLoss," takeProfit:",takeProfit);

      orderBook[i-1]=OrderSend(Symbol(),orderType2,lots*lotMult,openPrice,0,stopLoss,takeProfit,NULL,0,0,clrGray);

      if(orderBook[i-1]!=-1)
        {
         if(OrderSelect(orderBook[i-1],SELECT_BY_TICKET))
           {
            Print(i,"TH OrderSend() P:",openPrice," SL:",stopLoss," TP:",takeProfit);
            Print(i,"TH OrderSelect() P:",OrderOpenPrice()," SL:",OrderStopLoss()," TP:",OrderTakeProfit());
            Print(i,"TH TP-P:",NormalizeDouble(OrderTakeProfit()-OrderOpenPrice(),Digits),"==",NormalizeDouble(orderDistance*multTP*Point,Digits),
                        " P-SL:",NormalizeDouble(OrderOpenPrice()-OrderStopLoss(),Digits),"==",NormalizeDouble(orderDistance*Point,Digits));
           }
         else
           {
            Print("ORDER ",orderBook[i-1]," NOT SELECTED");
           }
        }
      else
        {
         Print(i,"TH ORDER NOT PLACED ",GetLastError());
        }
     }
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
   bool tradeDecision = FALSE;                           //Orders will be placed only if decision to trade becomes true.
   double t1, t2, t3;                                    //Create points to detect hill/trough shape
//---
   t1 = iMACD(NULL,0,macdFastEMA,macdSlowEMA,1,0,0,1);   //MACD reading on previous bar.
   t2 = iMACD(NULL,0,macdFastEMA,macdSlowEMA,1,0,0,2);   //MACD reading 2 bars ago.
   t3 = iMACD(NULL,0,macdFastEMA,macdSlowEMA,1,0,0,3);
//---
   if(t2>t1 && t2>=t3 && t2>(macdThreshold*Point))       //If middle point is above the other & above some threshold point
     {
      tradeDecision = TRUE;                              //Decided to trade
      direction = clrRed;                                //Direction to trade is SELL
     }
   if(t2<t1 && t2<=t3 && t2<(macdThreshold*Point*(-1)))  //If trough
     {
      tradeDecision = TRUE;
      direction = clrGreen;
     }
   if(tradeDecision){Print("SHAPE DETECTED");}
//---
   return(tradeDecision);
   }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
