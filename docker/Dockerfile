FROM openjdk
WORKDIR /home
ADD https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar .
#ADD https://raw.githubusercontent.com/FranckPachot/ybdemo/main/src/main/java/YBDemo.java .
#ADD https://search.maven.org/remotecontent?filepath=com/zaxxer/HikariCP/5.0.1/HikariCP-5.0.1.jar ./HikariCP.jar
#ADD http://www.java2s.com/Code/JarDownload/slf4j-simple/slf4j-simple-1.6.1.jar.zip ./slf4j-simple.jar
#ADD https://github.com/yugabyte/pgjdbc/releases/download/v1.0.0/jdbc-yugabytedb-42.3.0.jar ./jdbc-yugabytedb.jar
#ENV CLASSPATH=.:HikariCP.jar:slf4j-simple.jar:jdbc-yugabytedb.jar
#RUN javac YBDemo.java
COPY ./hikari.properties .
COPY ./ybdemo.sql .
#CMD java -jar YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar < ./ybdemo.sql
#CMD ["/bin/ping","localhost"]
CMD ["java","-jar","YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar"]
#COPY . /usr/src/myapp
#WORKDIR /usr/src/myapp
#RUN javac Main.java
#CMD ["java", "Main"]

