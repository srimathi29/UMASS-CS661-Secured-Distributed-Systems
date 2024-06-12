// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

import "./IERC223.sol";
import "./ERC223.sol";
import "./ownable.sol";

abstract contract ITokenHolder is IERC223Recipient, Ownable
{
    IERC223 public currency;
    uint256 public pricePer;  // In wei
    uint256 public amtForSale;

    // Return the current balance of ethereum held by this contract
    function ethBalance() view external returns (uint)
    {
        return address(this).balance;
    }
    
    // Return the quantity of tokens held by this contract
    function tokenBalance() virtual external view returns(uint);

    // indicate that this contract has tokens for sale at some price, so buyFromMe will be successful
    function putUpForSale(uint /*amt*/, uint /*price*/) virtual public
    {
        assert(false);
    }
 
    // This function is called by the buyer to pay in ETH and receive tokens.  Note that this contract should ONLY sell the amount of tokens at the price specified by putUpForSale!
    function sellToCaller(address /*to*/, uint /*qty*/) virtual external payable
    {
        assert(false);
    }
   
  
    // buy tokens from another holder.  This is OPTIONALLY payable.  The caller can provide the purchase ETH, or expect that the contract already holds it.
    function buy(uint /*amt*/, uint /*maxPricePer*/, TokenHolder /*seller*/) virtual public payable onlyOwner
    {
        assert(false);
    }
    
    // Owner can send tokens
    function withdraw(address /*_to*/, uint /*amount*/) virtual public onlyOwner
    {
        assert(false);
    }

    // Sell my tokens back to the token manager
    function remit(uint /*amt*/, uint /*_pricePer*/, TokenManager /*mgr*/) virtual public onlyOwner payable
    {
        assert(false);
    }
    
    // Validate that this contract can handle tokens of this type
    // You need to define this function in your derived classes, but it is already specified in IERC223Recipient
    //function tokenFallback(address _from, uint /*_value*/, bytes memory /*_data*/) override external

}

contract TokenHolder is ITokenHolder
{
    constructor(IERC223 _cur)
    {
        currency = _cur;
    }
    
    // Implement all ITokenHolder functions and tokenFallback
  
    /* When this holder intends to sell tokens for ETH, the buyer invokes this function to make a payment in ETH and obtain the corresponding tokens. */
    function sellToCaller(address to, uint amount) virtual override public payable
    {
        require(amtForSale > 0, "Nothing available for sale"); 
        require(amount <= amtForSale, "Attempting to buy too many tokens");
        require(msg.value >= pricePer*amount, "Not enough ETH");  // they paid me what was expected
        amtForSale -= amount;
        currency.transfer(to, amount);
    }
    
    /* Indicates that this contract offers tokens for sale at a specific price, ensuring the success of the buyFromMe transaction. */
    function putUpForSale(uint qty, uint price) override public onlyOwner
    {
        pricePer = price;
        amtForSale = qty;
    }
    
    
    /* Sell tokens back to the token manager */
    function remit(uint qty, uint _pricePer, TokenManager mgr) override public onlyOwner payable
    {
        putUpForSale(qty, _pricePer);
        mgr.buyFromCaller{value: mgr.fee(qty)}(qty);
    }

    /* Function for the owner to buy tokens from another holder */
    function buy(uint qty, uint maxPricePer, TokenHolder seller) public override payable onlyOwner {
        uint sellerPrice = uint(seller.pricePer());
        require(maxPricePer >= sellerPrice, "Low purchase price");

        uint balance = currency.balanceOf(address(this));
        seller.sellToCaller{value: sellerPrice * qty}(address(this), qty);

        require(currency.balanceOf(address(this)) == balance + qty, "Token purchase failed");
    }
    
    /* Function to validate that this contract can handle tokens of the given type */
    function tokenFallback(address, uint, bytes calldata) external override view {
        require(msg.sender == address(currency), "Wrong token type");
    }
    
    /*  Function for the owner to send tokens */
    function withdraw(address to, uint amount) public override onlyOwner {
        currency.transfer(to, amount);
    }

    
    /* Function to get the token balance held by this contract */
    function tokenBalance() external view override returns (uint) {
        return currency.balanceOf(address(this));
    }
}


contract TokenManager is ERC223Token, TokenHolder
{
    // Implement all functions
    using SafeMath for uint;
    uint private costPerToken=0;
    uint private TokenPerOpfee = 0;
    

    // Provide the price per token  and the fee per token to configure the manager's buying/selling operations.
    constructor(uint _price, uint _fee) TokenHolder(this) payable
    {
        costPerToken = _price;
        TokenPerOpfee = _fee;
    }
    
    // Calculate the total price for the given quantity of tokens
    function price(uint amt) public view returns(uint) 
    {  
        return amt*costPerToken; 
    }

    // Calculate the total fee for the given quantity of tokens
    function fee(uint amt) public view returns(uint) 
    {  
        return amt*TokenPerOpfee; 
    }
    
    // Allow a buyer to purchase tokens from this contract
    function sellToCaller(address to, uint amount) payable override public
    {
        require(msg.value >= amount*(costPerToken + TokenPerOpfee), "Not enough ETH!");
        if (balanceOf(address(this)) < amount){
           mint(amount);
        }
        ERC223Token token = ERC223Token(this);
        token.transfer(to,amount);
    }
    
    // Allow a seller to sell tokens to this contract
    function buyFromCaller(uint amount) public payable
    {
        require(msg.value >= amount*TokenPerOpfee, "Low fee!");
        uint256 curr_balance = balanceOf(address(this)); 
        
        TokenHolder th = TokenHolder(msg.sender);
        th.sellToCaller{value: (amount*costPerToken)}(address(this), amount); 
        
        require(balanceOf(address(this)) >= curr_balance + amount,"No transfer took place"); 
    }
    
    
    // Create new tokens and allocate them to this TokenManager
    function mint(uint amount) internal onlyOwner
    {
        _totalSupply = _totalSupply.add(amount);
        balances[address(this)] = balances[address(this)].add(amount);
    }
    
    // Destroy existing tokens owned by this TokenManager
    function melt(uint amount) external onlyOwner
    {
        require(balanceOf(address(this)) >= amount, "Attempted to melt more coins than manager owns");
        assert(_totalSupply >= amount);
        _totalSupply = _totalSupply.sub(amount);
        balances[address(this)] = balances[address(this)].sub(amount);
    }
}


//contract AATest
//{
   // event Log(string info);

    //function TestBuyRemit() payable public returns (uint)
    //{
      //  emit Log("trying TestBuyRemit");
        //TokenManager tok1 = new TokenManager(100,1);
       // TokenHolder h1 = new TokenHolder(tok1);

       // uint amt = 2;
       // tok1.sellToCaller{value:tok1.price(amt) + tok1.fee(amt)}(address(h1),amt);
       // assert(tok1.balanceOf(address(h1)) == amt);

       // h1.remit{value:tok1.fee(amt)}(1,50,tok1);
       // assert(tok1.balanceOf(address(h1)) == 1);
       // assert(tok1.balanceOf(address(tok1)) == 1);
        
       // return tok1.price(1);
    //} 
    
    //function FailBuyBadFee() payable public
    //{
       // TokenManager tok1 = new TokenManager(100,1);
       // TokenHolder h1 = new TokenHolder(tok1);

       // uint amt = 2;
       // tok1.sellToCaller{value:1}(address(h1),amt);
       // assert(tok1.balanceOf(address(h1)) == 2);
    //}
    
   //function FailRemitBadFee() payable public
    //{
       // TokenManager tok1 = new TokenManager(100,1);
       // TokenHolder h1 = new TokenHolder(tok1);

       // uint amt = 2;
       // tok1.sellToCaller{value:tok1.price(amt) + tok1.fee(amt)}(address(h1),amt);
       // assert(tok1.balanceOf(address(h1)) == amt);
       // emit Log("buy complete");
        
       // h1.remit{value:tok1.fee(amt-1)}(2,50,tok1);
    //} 
      
    //function TestHolderTransfer() payable public
    //{
       // TokenManager tok1 = new TokenManager(100,1);
       // TokenHolder h1 = new TokenHolder(tok1);
       // TokenHolder h2 = new TokenHolder(tok1);
        
       // uint amt = 2;
       // tok1.sellToCaller{value:tok1.price(amt) + tok1.fee(amt)}(address(h1),amt);
       // assert(tok1.balanceOf(address(h1)) == amt);
        
       // h1.putUpForSale(2, 200);
       // h2.buy{value:2*202}(1,202,h1);
       // h2.buy(1,202,h1);  // Since I loaded money the first time, its still there now.       
    //}
    
//}



