import java.sql.*;
import java.util.*;
import com.zaxxer.hikari.*;

public class YBDemo extends Thread {

 private HikariDataSource ds;
 private String sql;

 public YBDemo(HikariDataSource ds, String sql) throws SQLException {
  this.ds=ds;
  this.sql=sql;
 }

  public void run() {
   Connection connection;
   ResultSet rs;
   long timer;
   for(;;) { // loop forever to grab a connection and execute the sql statement
    timer=System.nanoTime();
    try {
     connection=ds.getConnection();
     rs = connection.createStatement().executeQuery(sql);
     rs.next(); // display only first row and one column
     System.out.println(String.format("%9s %6.0fms: %s",currentThread().getName(),(System.nanoTime()-timer)/1e6,rs.getString(1)));
     connection.close();
     } catch(SQLException e) {
      System.out.println(String.format("%9s %6.0fms SQLSTATE(%5s) %s",currentThread().getName(),(System.nanoTime()-timer)/1e6,e.getSQLState(),e) );
      // exit on non retryable errors (like transaction conflict or connection errors) https://www.postgresql.org/docs/current/errcodes-appendix.html
      if (!(e.getSQLState().startsWith("40") || e.getSQLState().startsWith("08") || e.getSQLState().startsWith("57") || e.getSQLState().startsWith("53"))) { 
      // exit the program on those errors
      System.exit(2);
      return ; 
      }
     }
    }
   }
   public static void main(String[] args) throws SQLException , InterruptedException {
     HikariConfig config = new HikariConfig( "hikari.properties" );
     HikariDataSource ds = new HikariDataSource ( config );
     if (ds.getConnectionInitSql() != null) {
      System.out.println("--------------------------------------------------");
      System.out.println("sql executed in each new connection:");
      System.out.println("--------------------------------------------------");
      System.out.println(ds.getConnectionInitSql().toString());
     }
     System.out.println("--------------------------------------------------");
     YBDemo thread;
     Scanner input = new Scanner(System.in);
     System.out.println("input lines will start a thread to execute in loop");
     System.out.println("--------------------------------------------------");
     while (input.hasNextLine()){
      thread=new YBDemo(ds,input.nextLine());
      thread.start();
     }
  }
 }
