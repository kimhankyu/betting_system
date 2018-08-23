pragma solidity ^0.4.17;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract Betting is StandardToken{
    using SafeMath for uint256;

    enum Result {NULL ,HOMETEAMWIN, AWAYTEAMWIN}        //NULL 초기값 & 무승부

 
    struct Game{            //게임 정보
        string homeTeam;
        string awayTeam;
        string date;
        uint32 homeTeamGoals;
        uint32 awayTeamGoals;
        uint32 homeTeamPenaltyGoals;   //승부차기
        uint32 awayTeamPenaltyGoals;    
        Result gameResult;
    }

    struct Bet{
        address myAdd;
        uint betMoney;      //배팅한 금액 기록
        uint32 betGameId;
        Result pResult;
        uint resMoney;
    }

    mapping (uint32 => Game) public games;
    mapping (uint32 => Bet[]) public BetByGameid;
    mapping (address => Bet[]) public BetByAddress;
    uint32[] gameIDs;

    address public account1 = 0x75b8EcCB3993BC5cB0501dD5B0522E95614BfDed;   //돈 모으는 주소
  
    //게임 추가
    function addGame(uint32 _gameId, string _homeTeam, string _awayTeam, string _date) public{
        require(msg.sender == account1);            //배포자인지 검사
        gameIDs.push(_gameId);
        games[_gameId].homeTeam = _homeTeam;
        games[_gameId].awayTeam = _awayTeam;
        games[_gameId].date = _date;
        games[_gameId].homeTeamGoals = 0;
        games[_gameId].awayTeamGoals = 0;
        games[_gameId].homeTeamPenaltyGoals = 0;
        games[_gameId].awayTeamPenaltyGoals = 0;
        games[_gameId].gameResult = Result.NULL;
    }

    //배팅
    function betting(uint32 _gameId, uint _betMoney, Result _gameResult) public payable{    
        //잔액이 배팅금액보다 더 큰금액인지는 java파일에서 확인한다.
        //msg.sender.balance 가 infura환경에서 버그
        account1.transfer(_betMoney);
        BetByGameid[_gameId].push(Bet(msg.sender, _betMoney, _gameId, _gameResult,0));
        BetByAddress[msg.sender].push(Bet(msg.sender, _betMoney, _gameId, _gameResult,0));
    }

    //내가 배팅한 총액
    function getMyTotalBettingMoney() public view returns(uint){       
        uint totalBetMoney = 0;
        for(uint i = 0; i < BetByAddress[msg.sender].length; i++){
            totalBetMoney = totalBetMoney.add(BetByAddress[msg.sender][i].betMoney);   //수정할 것
        }
        return totalBetMoney;
    }

    //게임 결과
    function ResultGame(uint32 _gameId, uint32 _homeTeamGoals, uint32 _awayTeamGoals, uint32 _homeTeamPenaltyGoals, uint32 _awayTeamPenaltyGoals) public{
        require(msg.sender == account1);            //배포자인지 검사
        games[_gameId].homeTeamGoals = _homeTeamGoals;
        games[_gameId].awayTeamGoals = _awayTeamGoals;
        if(_homeTeamGoals > _awayTeamGoals){
            games[_gameId].gameResult = Result.HOMETEAMWIN;
        }else if(_homeTeamGoals < _awayTeamGoals){
            games[_gameId].gameResult = Result.AWAYTEAMWIN;
        }else if(_homeTeamGoals == _awayTeamGoals){
            games[_gameId].homeTeamPenaltyGoals = _homeTeamPenaltyGoals;
            games[_gameId].awayTeamPenaltyGoals = _awayTeamPenaltyGoals;
            if(_homeTeamPenaltyGoals > _awayTeamPenaltyGoals){
                games[_gameId].gameResult = Result.HOMETEAMWIN;
            }else if(_homeTeamPenaltyGoals < _awayTeamPenaltyGoals){
                games[_gameId].gameResult = Result.AWAYTEAMWIN;
            }else{
                games[_gameId].gameResult = Result.NULL;
            }
        }
    }

    //돈 분배
    function moneyDivision(uint32 _gameId) public payable{  
        require(msg.sender == account1);            //배포자인지 검사
        uint totalMoney = getBettingMoneyByGameid(_gameId);
        uint winnerTotalMoney = 0;
        uint divisionMoney = 0;
        for(uint i = 0; i < BetByGameid[_gameId].length; i++){     
            if(BetByGameid[_gameId][i].pResult == games[_gameId].gameResult){
                winnerTotalMoney = winnerTotalMoney.add(BetByGameid[_gameId][i].betMoney);
            }
        }
        for(uint j = 0; j < BetByGameid[_gameId].length; j++){            
            if(BetByGameid[_gameId][j].pResult == games[_gameId].gameResult){
                divisionMoney = totalMoney.div(winnerTotalMoney);
                divisionMoney = divisionMoney.mul(BetByGameid[_gameId][j].betMoney);
                BetByGameid[_gameId][j].myAdd.transfer(divisionMoney);

                for(uint k=0; k < BetByAddress[msg.sender].length; k++){
                    if(BetByAddress[msg.sender][k].betGameId == _gameId){
                        BetByAddress[msg.sender][k].resMoney = divisionMoney;
                    }
                }
            }
        }
    }
  
    //해당 게임에 사람들이 배팅한 금액
    function getBettingMoneyByGameid(uint32 _gameId) public view returns (uint){
        uint totalBettingMoney = 0;
        for(uint i = 0; i < BetByGameid[_gameId].length ; i++){
            totalBettingMoney = totalBettingMoney.add(BetByGameid[_gameId][i].betMoney);
        }
        return totalBettingMoney;
    }

    //gameid 별 경기 결과
    function getGameInfo(uint32 _gameId) public view returns (uint32,uint32,uint32,uint32,Result){   
        return (games[_gameId].homeTeamGoals, games[_gameId].awayTeamGoals,games[_gameId].homeTeamPenaltyGoals,games[_gameId].awayTeamPenaltyGoals,games[_gameId].gameResult);
    }
    
    //내가 배팅한 경기 결과전 
    function getBetByAddressInfo(uint i) public view returns (uint32, uint, Result, uint){
        return (BetByAddress[msg.sender][i].betGameId, BetByAddress[msg.sender][i].betMoney, BetByAddress[msg.sender][i].pResult, BetByAddress[msg.sender][i].resMoney);
    }
    
    function getBetByAddressLength() public view returns(uint) {
        return BetByAddress[msg.sender].length;
    }

    //주소 확인
    function getAddress()  public view returns (address){
        return msg.sender;
    }

    //잔액 확인 (infura환경에서 버그있음)
    function getBalance()  public view returns (uint){      
        return msg.sender.balance;
    }

    function getGameIDsLen() public view returns (uint){
        return gameIDs.length;
    }
    
    function getGameIDsByint(uint i) public view returns (uint32){
        return gameIDs[i];
    }
}