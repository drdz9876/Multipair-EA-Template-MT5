//+------------------------------------------------------------------+
//|                                        Multipair EA Template.mq5 |
//|                                                   Copyright 2023 |
//|                                               drdz9876@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, drdz9876@gmail.com"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh> CTrade trade;

enum SLMode
  {
   Common,  //Common SL
   OwnSL    //Own SL
  };

input bool                 EnableMartin                  = true;  //Enable Martingale
input SLMode               SLType                        = OwnSL; //SL Type
input int                  maxOrders                     = 4;    //Max Orders
input double               Multiplier                    = 1.5;  //Lot Multiplier
input double               minDist                       = 20;    //Distance

input double Lot              = 0.01;      //Starting Lot
input int    StopLoss         = 95;    //Stoploss
input int    TakeProfit       = 95;  //TakeProfit
input bool   EnableTrail      = true; //Enable Trail
input int    TrailingStop     = 33; // Trailing Stop
input int    TrailingStep     = 10;// Trailing Step
input int    Magic            = 1; // Magic Number
input string Commentary       = "Multipair EA Template";   //EA Comment
input int    Slippage         = 10;  // Tolerated slippage in brokers' pips
input bool   TradeMultipair     = false; // Trade Multipair
input string PairsToTrade      = "EURUSD,GBPUSD,USDCHF"; //Pair to Trade
//input string PairsToTrade      = "AUDCAD,AUDCHF,AUDJPY,AUDNZD,AUDUSD,CADCHF,CADJPY,CHFJPY,EURAUD,EURCAD,EURCHF,EURGBP,EURJPY,EURNZD,EURUSD,GBPAUD,GBPCAD,GBPCHF,GBPJPY,GBPNZD,GBPUSD,NZDCAD,NZDCHF,NZDJPY,NZDUSD,USDCAD,USDCHF,USDJPY"; //Symbols To Trade

int      NoOfPairs;           // Holds the number of pairs passed by the user via the inputs screen
string   TradePair[];         //Array to hold the pairs traded by the user
int  bar = 20;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class EA
  {
public:
   int               ma1;
   int               ma2;
   void              Trade(string sym);

private:
   void              Trailing(string sym);
   bool              compareDoubles(string sym,double val1, double val2);
   int               Signal(string sym);
   double            lotAdjust(string sym, double lots);
   void              Martingale(string sym);

protected:
   bool              CheckMoneyForTrade(string sym, double lots,ENUM_ORDER_TYPE type);
   bool              CheckVolumeValue(string sym, double volume);


  };
EA start[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(Slippage);
   if(!TradeMultipair)
     {
      //Fill the array with only chart pair
      NoOfPairs = 1;
      ArrayResize(TradePair, NoOfPairs);
      ArrayResize(start, NoOfPairs);
      TradePair[0] = Symbol();
      start[0].ma1=iMA(TradePair[0],Period(),20,0,MODE_EMA,PRICE_CLOSE);
      start[0].ma2=iMA(TradePair[0],Period(),50,0,MODE_EMA,PRICE_CLOSE);
     }
   else
     {
      NoOfPairs = StringFindCount(PairsToTrade,",")+1;
      ArrayResize(TradePair, NoOfPairs);
      ArrayResize(start, NoOfPairs);
      string AddChar = StringSubstr(Symbol(),6, 4);
      StrPairToStringArray(PairsToTrade, TradePair, AddChar);
      for(int i = 0; i<NoOfPairs; i++)
        {
         start[i].ma1=iMA(TradePair[i],Period(),20,0,MODE_EMA,PRICE_CLOSE);
         start[0].ma2=iMA(TradePair[i],Period(),50,0,MODE_EMA,PRICE_CLOSE);
        }
     }
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int StringFindCount(string str, string str2)
//+------------------------------------------------------------------+
// Returns the number of occurrences of STR2 in STR
// Usage:   int x = StringFindCount("ABCDEFGHIJKABACABB","AB")   returns x = 3
  {
   int c = 0;
   for(int i=0; i<StringLen(str); i++)
      if(StringSubstr(str,i,StringLen(str2)) == str2)
         c++;
   return(c);
  } // End int StringFindCount(string str, string str2)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void StrPairToStringArray(string str, string &a[], string p_suffix, string delim=",")
//+------------------------------------------------------------------+
  {
   int z1=-1, z2=0;
   for(int i=0; i<ArraySize(a); i++)
     {
      z2 = StringFind(str,delim,z1+1);
      a[i] = StringSubstr(str,z1+1,z2-z1-1) + p_suffix;
      if(z2 >= StringLen(str)-1)
         break;
      z1 = z2;
     }
   return;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   return;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(TradeMultipair)
     {
      for(int i = 0; i<NoOfPairs; i++)
        {
         start[i].Trade(TradePair[i]);
        }
     }
   else
     {
      start[0].Trade(TradePair[0]);
     }


   return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void EA::Trailing(string sym)
  {
   double ask = 0, bid = 0, points = 0;
   int digits = 0, stopLevel = 0, spread = 0;
   double TS = 0, TST = 0;
   double opB = 0, ltB = 0, opS = 0, ltS = 0;
   int b = 0, s = 0, count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionGetTicket(i))
         if(PositionGetString(POSITION_SYMBOL) == sym)
            if(PositionGetInteger(POSITION_MAGIC) == Magic)
              {
               count++;
               ask = SymbolInfoDouble(sym,SYMBOL_ASK);
               bid = SymbolInfoDouble(sym,SYMBOL_BID);
               points = SymbolInfoDouble(sym,SYMBOL_POINT);
               digits = (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
               stopLevel = (int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
               spread = (int)SymbolInfoInteger(sym,SYMBOL_SPREAD);

               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                 {
                  b++;
                  opB += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                 }
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                 {
                  s++;
                  opS += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                 }
              }
     }

   double Margin = AccountInfoDouble(ACCOUNT_BALANCE);
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionGetTicket(i))
         if(PositionGetString(POSITION_SYMBOL) == sym)
            if(PositionGetInteger(POSITION_MAGIC) == Magic)
              {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                 {
                  TS  = TrailingStop * points;
                  TST  = TrailingStep * points;

                  if(b == 1)
                    {
                     if((PositionGetDouble(POSITION_SL) == 0 || (PositionGetDouble(POSITION_SL) != 0 && PositionGetDouble(POSITION_SL) < opB)) && bid - opB > TS)
                       {
                        if(!trade.PositionModify(PositionGetInteger(POSITION_TICKET),NormalizeDouble(opB + TS,digits),PositionGetDouble(POSITION_TP)))
                           Print(sym+" Trail Buy 1 Error "+ IntegerToString(GetLastError()));
                       }
                     if(PositionGetDouble(POSITION_SL) != 0 && PositionGetDouble(POSITION_SL) > opB && bid - PositionGetDouble(POSITION_SL) > TS)
                       {
                        if(!trade.PositionModify(PositionGetInteger(POSITION_TICKET),NormalizeDouble(PositionGetDouble(POSITION_SL) + TST,digits),PositionGetDouble(POSITION_TP)))
                           Print(sym+" Trail Buy 2 Error "+ IntegerToString(GetLastError()));
                       }
                    }
                 }
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                 {
                  TS  = TrailingStop * points;
                  TST  = TrailingStep * points;

                  if(s == 1)
                    {
                     if((PositionGetDouble(POSITION_SL) == 0 || (PositionGetDouble(POSITION_SL) != 0 && PositionGetDouble(POSITION_SL) > opS)) && opS - ask > TS)
                       {
                        if(!trade.PositionModify(PositionGetInteger(POSITION_TICKET),NormalizeDouble(opS - TST,digits),PositionGetDouble(POSITION_TP)))
                           Print(sym+" Trail Sell 1 Error "+ IntegerToString(GetLastError()));
                       }
                     if(PositionGetDouble(POSITION_SL) != 0 && PositionGetDouble(POSITION_SL) < opS && PositionGetDouble(POSITION_SL) - ask > TS)
                       {
                        if(!trade.PositionModify(PositionGetInteger(POSITION_TICKET),NormalizeDouble(PositionGetDouble(POSITION_SL) - TST,digits),PositionGetDouble(POSITION_TP)))
                           Print(sym+" Trail Sell 2 Error "+ IntegerToString(GetLastError()));
                       }
                    }
                 }
              }
     }

   return;
   ResetLastError();
  }
//+------------------------------------------------------------------+
void EA::Trade(string sym)
  {
   double ask = SymbolInfoDouble(sym,SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym,SYMBOL_BID);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);

   int countSym = 0, countOpen = 0,b=0,s=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionGetTicket(i)) // selects the position by index for further access to its properties
        {
         if(PositionGetInteger(POSITION_MAGIC)==Magic)
           {
            countSym++;
            if(PositionGetString(POSITION_SYMBOL)==sym)
              {
               countOpen++;
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  b++;
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                  s++;
              }
           }
        }
     }

   double SLbuy = 0, TPbuy = 0, SLsell = 0, TPsell = 0;

   if(StopLoss > 0)
     {
      SLbuy = ask - StopLoss * point;
      SLsell = bid + StopLoss * point;
     }
   if(TakeProfit > 0)
     {
      TPbuy = ask + TakeProfit * point;
      TPsell = bid - TakeProfit * point;
     }

   if(countOpen == 0)
     {
      if(Signal(sym) == 1)
        {
         if(CheckMoneyForTrade(sym,lotAdjust(sym,Lot),ORDER_TYPE_BUY) && CheckVolumeValue(sym,lotAdjust(sym,Lot)))
            if(b == 0)
               trade.Buy(lotAdjust(sym,Lot),sym,ask,SLbuy,TPbuy,Commentary);
        }
      else
         if(Signal(sym) == -1)
           {
            if(CheckMoneyForTrade(sym,lotAdjust(sym,Lot),ORDER_TYPE_SELL) && CheckVolumeValue(sym,lotAdjust(sym,Lot)))
               if(s == 0)
                  trade.Sell(lotAdjust(sym,Lot),sym,bid,SLsell,TPsell,Commentary);
           }
     }

   if(EnableTrail)
      Trailing(sym);

   if(EnableMartin)
      Martingale(sym);

   return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EA::compareDoubles(string sym, double val1, double val2)
  {
   int digits = (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   if(NormalizeDouble(val1 - val2,digits-1)==0)
      return (true);

   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void EA::Martingale(string sym)
  {
   double ask = SymbolInfoDouble(sym,SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym,SYMBOL_BID);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   int stopLevel = (int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
   int spread = (int)SymbolInfoInteger(sym,SYMBOL_SPREAD);

   double
   BuyPriceMax=0,BuyPriceMin=0,BuyPriceMaxLot=0,BuyPriceMinLot=0,
   SelPriceMin=0,SelPriceMax=0,SelPriceMinLot=0,SelPriceMaxLot=0,
   tpS1 = 0, tpB1 = 0;

   ulong
   BuyPriceMaxTic=0,BuyPriceMinTic=0,SelPriceMaxTic=0,SelPriceMinTic=0;

   ulong tkb= 0,tks=0;

   double
   opB=0,opS=0,lt=0,tpb=0,tps=0, slb=0,sls=0;

   double opBE = 0, ltB = 0, ltBE = 0, opSE = 0, ltS = 0, ltSE = 0, BEBuy = 0, BESell = 0, BuySL = 0, SellSL = 0;

   int countSym = 0,OpenPos = 0, b = 0, s = 0;
   for(int k=PositionsTotal()-1; k>=0; k--)
     {
      if(PositionGetTicket(k))
        {
         if(PositionGetString(POSITION_SYMBOL)==sym)
           {
            countSym++;
            if(PositionGetInteger(POSITION_MAGIC)==Magic)
              {
               OpenPos++;
               if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
                 {
                  b++;
                  opB=NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN),digits);
                  tpb = NormalizeDouble(PositionGetDouble(POSITION_TP),digits);
                  slb = NormalizeDouble(PositionGetDouble(POSITION_SL),digits);
                  tkb = PositionGetInteger(POSITION_TICKET);
                  ltB=NormalizeDouble(PositionGetDouble(POSITION_VOLUME),2);
                  opBE += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                  ltBE += PositionGetDouble(POSITION_VOLUME);
                  BEBuy = opBE/ltBE;
                  if(opB>BuyPriceMax || BuyPriceMax==0)
                    {
                     BuyPriceMax    = opB;
                     BuyPriceMaxLot = ltB;
                     BuyPriceMaxTic = tkb;
                    }
                  if(opB<BuyPriceMin || BuyPriceMin==0)
                    {
                     BuyPriceMin    = opB;
                     BuyPriceMinLot = ltB;
                     BuyPriceMinTic = tkb;
                    }
                 }
               // ===
               else
                  if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
                    {
                     s++;
                     opS=NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN),digits);
                     tps = NormalizeDouble(PositionGetDouble(POSITION_TP),digits);
                     sls = NormalizeDouble(PositionGetDouble(POSITION_SL),digits);
                     ltS=NormalizeDouble(PositionGetDouble(POSITION_VOLUME),2);
                     tks = PositionGetInteger(POSITION_TICKET);
                     opSE+= PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                     ltSE += PositionGetDouble(POSITION_VOLUME);
                     BESell = opSE/ltSE;
                     if(opS>SelPriceMax || SelPriceMax==0)
                       {
                        SelPriceMax    = opS;
                        SelPriceMaxLot = ltS;
                        SelPriceMaxTic = tks;
                       }
                     if(opS<SelPriceMin || SelPriceMin==0)
                       {
                        SelPriceMin    = opS;
                        SelPriceMinLot = ltS;
                        SelPriceMinTic = tks;
                       }
                    }
              }
           }
        }
     }
   if(SLType == OwnSL)
     {
      if(StopLoss > 0)
        {
         BuySL = ask - StopLoss * point;
         SellSL = bid + StopLoss * point;
        }
     }
   else
      if(SLType == Common)
        {
         if(StopLoss > 0)
           {
            BuySL = slb;
            SellSL = sls;
           }
        }

   double buyLot = 0, selLot = 0;

   buyLot = lotAdjust(sym,BuyPriceMaxLot * MathPow(Multiplier,b));
   selLot = lotAdjust(sym,SelPriceMinLot * MathPow(Multiplier,s));

   double PipSteps = 0, BuySteps = 0, SellSteps = 0;

   PipSteps = minDist * point;

   BuySteps = PipSteps;
   SellSteps = PipSteps;

   if(OpenPos < maxOrders)
     {
      if(b > 0)
        {
         if(BuyPriceMin - ask >= BuySteps)
           {
            if(CheckMoneyForTrade(sym,buyLot,ORDER_TYPE_BUY) && CheckVolumeValue(sym,buyLot))
              {
               trade.Buy(buyLot,sym,ask,BuySL,0,Commentary);
              }
           }
        }
      if(s > 0)
        {
         if(bid - SelPriceMax >= SellSteps)
           {
            if(CheckMoneyForTrade(sym,selLot,ORDER_TYPE_SELL) && CheckVolumeValue(sym,selLot))
              {
               trade.Sell(selLot,sym,bid,SellSL,0,Commentary);
              }
           }
        }
     }
   for(int uui=PositionsTotal()-1; uui>=0; uui--)
     {
      if(PositionGetTicket(uui))
        {
         if(PositionGetString(POSITION_SYMBOL)==sym)
            if(PositionGetInteger(POSITION_MAGIC)==Magic)
              {
               if(b>=2 && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
                 {
                  if(!compareDoubles(sym,PositionGetDouble(POSITION_TP),tpb))
                     if(!trade.PositionModify(PositionGetInteger(POSITION_TICKET),BuySL,tpb))
                        Print(sym+" Buy Martingale TP Average Failed "+IntegerToString(GetLastError()));
                 }
               if(s>=2 && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
                 {
                  if(!compareDoubles(sym,PositionGetDouble(POSITION_TP),tps))
                     if(!trade.PositionModify(PositionGetInteger(POSITION_TICKET),SellSL,tps))
                        Print(sym+" Sell Martingale TP Average Failed "+IntegerToString(GetLastError()));
                 }
              }
        }
     }
   return;
   ResetLastError();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EA::CheckMoneyForTrade(string sym, double lots,ENUM_ORDER_TYPE type)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(sym,mqltick);
   double price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
//--- values of the required and free margin
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
//--- call of the checking function
   if(!OrderCalcMargin(type,sym,lots,price,margin))
     {
      //--- something went wrong, report and return false
      return(false);
     }
//--- if there are insufficient funds to perform the operation
   if(margin>free_margin)
     {
      //--- report the error and return false
      return(false);
     }
//--- checking successful
   return(true);
  }
//************************************************************************************************/
bool EA::CheckVolumeValue(string sym, double volume)
  {

   double min_volume = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(volume < min_volume)
      return(false);

   double max_volume = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   if(volume > max_volume)
      return(false);

   double volume_step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   int ratio = (int)MathRound(volume / volume_step);
   if(MathAbs(ratio * volume_step - volume) > 0.0000001)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int EA::Signal(string sym)
  {
   double fast[],slow[];
   MqlRates rates[];

   ArrayResize(fast,bar);
   ArrayResize(slow,bar);
   ArrayResize(rates,bar);

   ArraySetAsSeries(fast,true);
   ArraySetAsSeries(slow,true);
   ArraySetAsSeries(rates,true);

   for(int x=bar-1; x>=0; x--)
     {
      CopyBuffer(ma1,0,x,2,fast);
      CopyBuffer(ma2,0,x,2,slow);
      CopyRates(sym,Period(),x,2,rates);
     }

   if(fast[0] > slow[0] && fast[1] < slow[1])
     {
      if(rates[1].close > fast[1] && rates[0].close > fast[0])
         return(1);
     }
   if(fast[0] < slow[0] && fast[1] > slow[1])
     {
      if(rates[1].close < fast[1] && rates[0].close < fast[0])
         return(-1);
     }

   return(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double EA::lotAdjust(string sym, double lots)
  {
   double value = 0;
   double lotStep = SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   double minLot  = SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   value  = lotStep * NormalizeDouble(lots / lotStep, 0);

   value = MathMax(MathMin(maxLot, value), minLot);

   return(value);
  }

//+------------------------------------------------------------------+
