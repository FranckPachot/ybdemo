cd $(dirname $0)
curl -Ls https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar > YBDemo.jar
case $1 in 
*)
   java -jar YBDemo.jar < ./ybdemo.sql ;;
esac
