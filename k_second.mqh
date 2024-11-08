//+------------------------------------------------------------------+
//|                                                k_second.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
class k_second
  {
public:
                     k_second(string _symbol_name,int _time_next,int _count_lit);//有参构造
                     k_second();
                    ~k_second();
   //---访问器
   int               ger_db() {return db;}
   string               ger_table_name() {return table_name;}
   bool              creat_table();
   //---没有逻辑的插入
   bool              insert_information_next();
   //---判断逻辑 插入数据
   void              insert_information();
   //---更新最大行数据
   bool              update_information();
   //---删除最小行数据
   int               get_count();
   bool              del_min_information();
   //---删除表
   bool              del_table();
   //---查询打印所有数据
   void              print_information();
   //---工作函数
   void              working(bool print_choose);
public:
   string            symbol_name;
   string            table_name;//表名
   int               db;//数据库句柄
   long              time_state;//更新时间标志
   int               time_next;//间隔更新时间标志
   int               count_lit;//工需要多少行数据
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
k_second::k_second()
  {
   this.time_next = 15;
   this.count_lit = 300;
   this.symbol_name = Symbol();
   time_state=0;
   string login = (string)AccountInfoInteger(ACCOUNT_LOGIN);
   table_name = symbol_name+login;
   db=DatabaseOpen(login+".db",DATABASE_OPEN_READWRITE|DATABASE_OPEN_CREATE|DATABASE_OPEN_COMMON);
   creat_table();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
k_second::k_second(string _symbol_name="",int _time_next=15,int _count_lit=300)
  {
   this.time_next = _time_next;
   this.count_lit = _count_lit;
   this.symbol_name = _symbol_name;
   if(this.symbol_name =="")
      this.symbol_name =Symbol();
   time_state=0;

   string login = (string)AccountInfoInteger(ACCOUNT_LOGIN);
   table_name = symbol_name+"_"+(string)time_next+"s_"+login;
   db=DatabaseOpen(login+".db",DATABASE_OPEN_READWRITE|DATABASE_OPEN_CREATE|DATABASE_OPEN_COMMON);
   creat_table();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
k_second::~k_second()
  {
   del_table();//删除表
   if(db!=INVALID_HANDLE)
     {
      DatabaseClose(db);
     }
  }
//+------------------------------------------------------------------+
bool k_second::creat_table()
  {
   if(!DatabaseTableExists(db, table_name))
     {
      string sql = StringFormat("CREATE TABLE %s ("
                                "TIME_C       INT   PRIMARY KEY NOT NULL,"
                                "OPEN         REAL,"
                                "HIGH         REAL,"
                                "LOW          REAL,"
                                "CLOSE        REAL);",table_name);
      Print(sql);
      bool chk= DatabaseExecute(db,sql);
      if(!chk)
        {
         Print(table_name+ "执行错误 ", GetLastError());
         return false;
        }
      else
         return true;
     }
   return true;
  }
//+------------------------------------------------------------------+
void k_second::insert_information()
  {
   long ref_time = TimeCurrent();
   if(ref_time>= time_state+time_next)
     {
      insert_information_next();//---调用
      time_state = ref_time;
     }
  }
//+------------------------------------------------------------------+
bool k_second::insert_information_next()
  {
   long   time = TimeCurrent();
   double open = SymbolInfoDouble(symbol_name,SYMBOL_BID);
   double high = SymbolInfoDouble(symbol_name,SYMBOL_BID);
   double low = SymbolInfoDouble(symbol_name,SYMBOL_BID);
   double close = SymbolInfoDouble(symbol_name,SYMBOL_BID);

   DatabaseTransactionBegin(db);
//--- add each deal using the following request
   string request_text=StringFormat("INSERT INTO %s (TIME_C,OPEN,HIGH,LOW,CLOSE)"
                                    "VALUES (%d, %G, %G, %G, %G)",table_name,time,open,high,low,close);
   if(!DatabaseExecute(db, request_text))
     {
      PrintFormat("insert ERROR ", __FUNCTION__, GetLastError());
      DatabaseTransactionRollback(db);
      return false;
     }
   DatabaseTransactionCommit(db);
   return true;
  }
//+------------------------------------------------------------------+
bool k_second::update_information()
  {
//---获取key最大值 TIME_C
   string request_text=StringFormat("SELECT max(TIME_C) FROM %s",table_name);
   int  request= DatabasePrepare(db,request_text);
   if(request==INVALID_HANDLE)
     {
      Print("max(TIME_C) ", GetLastError());
      return false;
     }
   DatabaseRead(request);//读取
   long time_current;
   DatabaseColumnLong(request,0,time_current);//获取最大值
   DatabaseFinalize(request);

//---查询结果
   request_text=StringFormat("SELECT * FROM %s where TIME_C == %d",table_name,time_current);
   request=DatabasePrepare(db,request_text);
   DatabaseRead(request);//读取
   double high= 0;
   double low = 0;
   DatabaseColumnDouble(request,2,high);//获取最高价
   DatabaseColumnDouble(request,3,low);//获取最低价
//---更新最新结果的最高价最低价收盘价
   double bid = SymbolInfoDouble(symbol_name,SYMBOL_BID);
   if(bid>high)
      high=bid;
   if(bid<low)
      low=bid;
   DatabaseFinalize(request);
//---更新数据
   request_text=StringFormat("UPDATE %s SET HIGH = %G, LOW = %G,CLOSE = %G where TIME_C == %d",table_name,high,low,bid,time_current);
   DatabaseTransactionBegin(db);
   if(!DatabaseExecute(db, request_text))
     {
      PrintFormat("update ERROR ", __FUNCTION__, GetLastError());
      DatabaseTransactionRollback(db);
      return false;
     }
   DatabaseTransactionCommit(db);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool k_second::del_min_information()
  {
   if(get_count()>=count_lit)
     {
      //---获取key最小值 TIME_C
      string  request_text=StringFormat("SELECT min(TIME_C) FROM %s",table_name);
      int  request= DatabasePrepare(db,request_text);
      if(request==INVALID_HANDLE)
        {
         Print("min(TIME_C) ", GetLastError());
         return false;
        }
      DatabaseRead(request);//读取
      long time_current;
      DatabaseColumnLong(request,0,time_current);//获取最小值
      DatabaseFinalize(request);

      request_text=StringFormat("DELETE FROM %s WHERE TIME_C == %d",table_name,time_current);
      bool chk = DatabaseExecute(db,request_text);
      return chk;
     }
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int k_second::get_count()
  {
//---获取行数
   string request_text=StringFormat("SELECT count(TIME_C) FROM %s",table_name);
   int  request= DatabasePrepare(db,request_text);
   if(request==INVALID_HANDLE)
     {
      Print("count(TIME_C) ", GetLastError());
      return false;
     }
   DatabaseRead(request);//读取
   int count;
   DatabaseColumnInteger(request,0,count);//获取最大值
   DatabaseFinalize(request);
   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool k_second::del_table()
  {
   string request_text=StringFormat("DROP TABLE IF EXISTS %s",table_name);
   bool chk = DatabaseExecute(db,request_text);
   return chk;
  }
//+------------------------------------------------------------------+
void k_second::print_information()
  {
//---查询结果
   string request_text=StringFormat("SELECT * FROM %s",table_name);
   DatabasePrint(db,request_text,0);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void k_second::working(bool print_choose=false)
  {
   del_min_information();
   insert_information();
   update_information();

   if(print_choose)
      print_information();
  }
//+------------------------------------------------------------------+
