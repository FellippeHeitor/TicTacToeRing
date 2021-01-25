<?php

# Tic Tac Toe Rings Scoreboard Updater. (Server Side PHP code)


#pass a 10 digit positive number value
#returns coded string representing the same number
#terminate with "invalid query" if there is error in coded string parameter
#Method By Ashish
function decodeNum ($c) {
    #if(strlen($c)!=10) {
        #exit('<p>authfailed</p>');
        #exit('function decodeNum($c): invalid length of $c');
    #}
    $num_table = " 0qA8dZ7vB1eY3yC6kX5bD9fW2xE4pV";
    $max_len = strlen($c);
    $n = 0;
    $j = "";
    $x = 0;
    for($i=0;$i<$max_len;$i++){
        $j = substr($c,$i,1);
        if(strpos($num_table,$j)) {
            $x = strpos($num_table,$j)-1;
            $n = $n*10 + (($x - ($x%3))/3);
        } else {
            exit('<p>authfailed</p>');
            #exit("function decodeNum($c): invalid code of $c : $j");
        }
    }
    return $n;
}

#pass a coded string returned by alphaStringToCode$
#returns the original UPPER CASED string
#terminate with "invalid query" if there is error in coded string parameter
#Method By Ashish
function decodeAlphaString ($c) {
    if(strlen($c)!=8){
        exit('<p>authfailed</p>');
        #exit('function decodeAlphaString($c): invalid length of $c');
    }
    $alpha_char_table = " qPaLzOwKsMxIeJdNcjXmEiSkZo";
    $num = " 0123456789";
    $j = "";
    $tmp = "";
    for($i=0;$i<=7;$i++){
        $j = substr($c,$i,1);
        if(strpos($num,$j)) {
            continue;
        } else {
            if(strpos($alpha_char_table,$j)) {
                $tmp.=chr(strpos($alpha_char_table,$j)+64);
            } else {
                exit('<p>authfailed</p>');
                #exit('function decodeAlphaString($c): invalid code of $c');
            }
        }
    }
    return $tmp;
}

#authentication
#terminate with "invalid query" if there is invalid key
#Method By Ashish
function verifyToken ($t) {
    if(strlen($t)<>16){
        exit('<p>authfailed</p>');
        #exit('function verifyToken($n): invalid length of $t');
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
        exit('<p>authfailed</p>');
        #exit('function verifyToken($t): failed verification');
    }
}
#####################################################################
#---------------------------DATA STRUCTURE--------------------------
#* Only a "single" string will be receive to us containing all data and authentication
#* First 10 chars/bytes -> random chars
#* Next 10 chars/bytes -> expire time (CODED)
#* Next 2 chars/bytes -> number of players in the board data (CODED)
#* Next 1 char/byte -> game mode (CODED)
#* Next contain board data of players (CODED) (NAME1 SCORE1 NAME2 SCORE2 ... and so on) NAME->8char/bytes, SCORE->5char/bytes
#* Next 16 chars/bytes -> authentication

if(isset($_GET['key'])){
    $key = $_GET['key']; 
} else {
    exit('<p>authfailed</p>'); #if no key is passed. maybe someone trying to hack it.
    #exit("'key' is not set");
}
#checking if the key has expired or not
$time_now = time();
$expire_time = decodeNum(substr($key,10,10));
if($time_now>$expire_time){
    exit('<p>authfailed</p>');
    #exit("time has expire. Expire time : $expire_time Current time : $time_now");
}
$num_of_players = decodeNum(substr($key,20,2));
#echo "num : $num_of_players <br>";
$mode = decodeNum(substr($key,22,1));
#echo "mode : $mode";
if(39+$num_of_players*13<>strlen($key)){
    exit('<p>authfailed</p>'); #someone trying to hack it by puting some random changes in the key.
    #exit("invalid length of 'key' passed");
}
#veryfing the authentication key
$auth_pos = 23+$num_of_players*13;
$auth = substr($key,$auth_pos,16);
#echo "auth : $auth <br>";
verifyToken($auth);
$i = 23;
$board_data = "";
while ($i<$auth_pos-1) {
    $player_name = decodeAlphaString(substr($key,$i,8));
    $player_score = decodeNum(substr($key,$i+8,5));
    $board_data.=chr(34).$player_name.chr(34).','.strval($player_score).',';
    $i+=13;
}
$board_data = substr($board_data,0,strlen($board_data)-1);
#echo "$num_of_players <br>";
#echo $board_data;
#putting contents into file

if($mode==1) {
    @file_put_contents('theboard_easier.txt', $board_data);
} else {
    @file_put_contents('theboard.txt', $board_data);
}
echo "<p>success</p>";

?>