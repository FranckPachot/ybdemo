import java.sql.*;
import java.util.*;
import com.zaxxer.hikari.*;

public class YBDemo extends Thread {

 private HikariDataSource ds;
 private String sql;
 // I'll use exponential backoff for serialization or HA errors ( YugabyteDB worst case for HA is 3 seconds )
 int max_retries=10;
 private void exponentialBackoffWait(int retry){
  // waits random milliseconds between 0 and 10 plus exponential (10ms for first retry, then 20,40,80,160,320,640,1280,2560,5120...)
  try {
   int ms=(int)(10*Math.random()+10*Math.pow(2,retry));
   Thread.sleep(ms);
   System.err.println(String.format(" wait in thread %9s %5d ms before retry",currentThread().getName(),ms));
   } catch (InterruptedException e) { System.err.println(e); }
 }

 // the thread takes one parameter: the sql command to execute
 public YBDemo(HikariDataSource ds, String sql) throws SQLException {
  this.ds=ds;
  this.sql=sql;
  }

 // each thread will connet and run the sql in a loop
 public void run() {
  Connection connection=null;
  ResultSet rs;
  long timer;
  int retries=0;
  for(;;) { 
   timer=System.nanoTime();
   try {
    // grab a connection from the pool
    connection=ds.getConnection();
    // execute the sql command (expects 1 column 1 row)
    rs = connection.createStatement().executeQuery(sql);
    // display only first row and one column - you can get it as one json with with row_to_json() or json_agg()
    rs.next(); 
    System.out.println(String.format("%9s %6.0fms: %s",currentThread().getName(),(System.nanoTime()-timer)/1e6,rs.getString(1)));
    // we suppose autocommit, just close the connection
    connection.close();
    // For demo purpose, errors will either continue the loop or exit the whole program (even if other threads are ok)
    } catch(SQLTransientConnectionException e) {
      // Error handling // connection pool error (no SQLSTATE): retry without waiting
      System.err.println(String.format("\n%s\nError in thread %9s %6.0fms connection pool - retry %d/%d\n%s"
       ,sql,currentThread().getName(),(System.nanoTime()-timer)/1e6,retries,max_retries,e) );
      // count the retry but don't wait (already waited connectionTimeout)
      retries++;
      if (retries>max_retries) { System.exit(5); }
    } catch(SQLException e) {
     // For demo purpose, displays exception and SQLSTATE (see https://www.postgresql.org/docs/current/errcodes-appendix.html)
      System.err.println(String.format("\n%s\nError in thread %9s %6.0fms SQLSTATE(%5s) - retry %s/%s\n%s"
       ,sql,currentThread().getName(),(System.nanoTime()-timer)/1e6,e.getSQLState(),retries,max_retries,e) );
     // Error handling // Application error: stop the thread
     if ( e.getSQLState().startsWith("02000") ) {
      // no data: stop the thread (I use it to run DDL once in my demos)
      return;
      }
     else if ( e.getSQLState().startsWith("42") ) {
      // syntax error: print the SQL and stop the program to fix the demo
      System.exit(4);
      }
     // Error handling // Retriable error: retry
     else if ( 
       e.getSQLState().startsWith("40001") || // Serialization error (optimistic locking conflict)
       e.getSQLState().startsWith("40P01") || // Deadlock
       e.getSQLState().startsWith("08006") || // Connection failure (node down, need to reconnect)
       e.getSQLState().startsWith("XX000")    // Internal error (may happen during HA)
       ) {
      // count the retry and wait exponentially ( a random between 0 and 10 milliseconds, plus 10ms for first retry, then 20,40,80...
      exponentialBackoffWait(retries);
      retries++;
      try { connection.close(); } catch (SQLException x) {}
      if (retries>max_retries) { System.exit(5); }
      }
     // Error handling // System error: stop the program
     else if ( e.getSQLState().startsWith("5") ) {
      System.exit(5);
      }
     // Error handling // Other error: stop the program - this is the best to know what we missed
     else {
      System.exit(255);
     }
    }
   // if we get there without errors, reset the retry count
   retries=0;
   }
  }
   public static void main(String[] args) throws SQLException , InterruptedException {
    System.err.println("--------------------------------------------------");
    System.err.println("----- YBDemo -- Franck Pachot -- 2022-02-06 ------");
    System.err.println("----- https://github.com/FranckPachot/ybdemo -----");
    System.err.println("--------------------------------------------------");
    try {
     // Tthe connection is defined in HikariCP properties
     HikariConfig config = new HikariConfig( "hikari.properties" );
     HikariDataSource ds = new HikariDataSource ( config );
     // I set parameters or prepare statements in connection init
     if (ds.getConnectionInitSql() != null) {
      System.err.println("--------------------------------------------------");
      System.err.println("sql executed in each new connection init:");
      System.err.println("--------------------------------------------------");
      System.err.println(ds.getConnectionInitSql().toString());
      }
     System.err.println("--------------------------------------------------");
     // each line read from stdin will start a thread to execute the line
     YBDemo thread;
     Scanner input = new Scanner(System.in);
     System.err.println("input lines will start a thread to execute in loop");
     System.err.println("--------------------------------------------------");
     String sql;
     while (input.hasNextLine()){
      sql=input.nextLine();
      System.err.println("\nStarting a thread for "+sql);
      thread=new YBDemo(ds,sql);
      // waiting before starting next thread (I may use first threads to create tables)
      Thread.sleep(1000);
      thread.start();
      }
     // Return code 1 is for errors from the main. Other Codes will be for thread errors
     } catch(SQLException e) {
      System.err.println(String.format("\nError in main:\n %s",e.getSQLState(),e) );
      System.exit(1);
      }
    }

   }
