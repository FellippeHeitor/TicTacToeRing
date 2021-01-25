<?php

#Tic Tac Toe Rings Game ScoreBoard Downloader

#authentication
#terminate with "invalid query" if there is invalid key
#Method By Ashish
function verifyToken ($t) {
    if(strlen($t)<>16){
        exit('authfailed');
    }
    $token_char_table = "0123456789QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm";
    $tmp = substr($t,0,8);
    $x = 0;
    for($i=0;$i<8;$i+=1){
        $x = (((ord(substr($tmp,$i,1))*101)+37)%62);
        $tmp.=substr($token_char_table,$x,1);
    }
    if($tmp==$t){
        return true;
    } else {
        exit('authfailed');
    }
}


if(isset($_GET['mode'])){
    $mode = $_GET['mode'];
    if($mode==2){echo "<p>".time()."</p>";exit();}
    if($mode==1){
        $board_data = @file_get_contents('theboard_easier.txt');
    } else {
        $board_data = @file_get_contents('theboard.txt');
    }
} else {
    exit('authfailed');
}

echo "<p>".$board_data."</p>";
?>