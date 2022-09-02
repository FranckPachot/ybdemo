/*

I use this in to run with "My Script" extension
https://microsoftedge.microsoft.com/addons/detail/my-script/pjnkcmipfmmcpehaoemnjlhlhjaeebog

*/

// table
if ( window.location.href.match(/:7000[/]table[?]id=[0-9a-z]*/) )
{
  
// reduces the side bar  
document.getElementsByClassName("yb-main container-fluid")[0].style.marginLeft="88px";
document.getElementsByClassName("sidebar-wrapper")[0].style.width="99px";
  
//  clock on "message" header to hide those columns
document.querySelectorAll(
    '.table-striped:nth-child(4) tr>th:nth-child(6)'
    ).forEach(el => el.onclick = 
function runme(){
document.querySelectorAll(
    '.table-striped:nth-child(4) tr>*:nth-child(n+3):nth-child(-n+6)'
    ).forEach(el => el.style
    .display = 'none');

}
);



}
