 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NFTBookClub
 * @dev A simplified decentralized book club with NFT books and rewards
 */
contract NFTBookClub {
    address public owner;
    uint256 public totalBooks;
    uint256 public rewardPool;
    uint256 public platformFee = 500; // 5% in basis points
    
    // Book structure
    struct Book {
        uint256 id;
        string title;
        string author;
        string contentHash;
        uint256 pages;
        uint256 price;
        uint256 reward;
        address publisher;
        bool active;
    }
    
    // NFT Token structure
    struct BookToken {
        uint256 id;
        uint256 bookId;
        address owner;
        uint256 currentPage;
        bool completed;
    }
    
    // Mappings
    mapping(uint256 => Book) public books;
    mapping(uint256 => BookToken) public tokens;
    mapping(address => uint256[]) public userTokens;
    mapping(uint256 => bool) public rewardClaimed;
    
    // Events
    event BookAdded(uint256 indexed bookId, string title, address publisher);
    event BookMinted(uint256 indexed tokenId, uint256 indexed bookId, address owner);
    event ProgressUpdated(uint256 indexed tokenId, uint256 page);
    event BookCompleted(uint256 indexed tokenId, address reader);
    event RewardClaimed(uint256 indexed tokenId, address reader, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyTokenOwner(uint256 _tokenId) {
        require(tokens[_tokenId].owner == msg.sender, "Not token owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Add a new book
     */
    function addBook(
        string memory _title,
        string memory _author,
        string memory _contentHash,
        uint256 _pages,
        uint256 _price,
        uint256 _reward
    ) external {
        require(bytes(_title).length > 0, "Empty title");
        require(_pages > 0, "Invalid pages");
        
        totalBooks++;
        
        books[totalBooks] = Book({
            id: totalBooks,
            title: _title,
            author: _author,
            contentHash: _contentHash,
            pages: _pages,
            price: _price,
            reward: _reward,
            publisher: msg.sender,
            active: true
        });
        
        emit BookAdded(totalBooks, _title, msg.sender);
    }
    
    /**
     * @dev Mint book as NFT
     */
    function mintBook(uint256 _bookId) external payable {
        require(_bookId > 0 && _bookId <= totalBooks, "Invalid book");
        require(books[_bookId].active, "Book not active");
        require(msg.value >= books[_bookId].price, "Insufficient payment");
        
        uint256 tokenId = totalBooks + userTokens[msg.sender].length + 1;
        
        tokens[tokenId] = BookToken({
            id: tokenId,
            bookId: _bookId,
            owner: msg.sender,
            currentPage: 0,
            completed: false
        });
        
        userTokens[msg.sender].push(tokenId);
        
        // Calculate fees
        uint256 fee = (msg.value * platformFee) / 10000;
        uint256 publisherPayment = msg.value - fee;
        
        // Add fee to reward pool
        rewardPool += fee;
        
        // Pay publisher
        (bool success, ) = books[_bookId].publisher.call{value: publisherPayment}("");
        require(success, "Payment failed");
        
        emit BookMinted(tokenId, _bookId, msg.sender);
    }
    
    /**
     * @dev Update reading progress
     */
    function updateProgress(uint256 _tokenId, uint256 _page) external onlyTokenOwner(_tokenId) {
        BookToken storage token = tokens[_tokenId];
        Book storage book = books[token.bookId];
        
        require(!token.completed, "Already completed");
        require(_page <= book.pages, "Invalid page");
        require(_page > token.currentPage, "Cannot go backward");
        
        token.currentPage = _page;
        
        emit ProgressUpdated(_tokenId, _page);
        
        // Check if completed
        if (_page == book.pages) {
            token.completed = true;
            emit BookCompleted(_tokenId, msg.sender);
        }
    }
    
    /**
     * @dev Claim reward for completed book
     */
    function claimReward(uint256 _tokenId) external onlyTokenOwner(_tokenId) {
        BookToken storage token = tokens[_tokenId];
        Book storage book = books[token.bookId];
        
        require(token.completed, "Not completed");
        require(!rewardClaimed[_tokenId], "Already claimed");
        require(rewardPool >= book.reward, "Insufficient reward pool");
        
        rewardClaimed[_tokenId] = true;
        rewardPool -= book.reward;
        
        (bool success, ) = msg.sender.call{value: book.reward}("");
        require(success, "Transfer failed");
        
        emit RewardClaimed(_tokenId, msg.sender, book.reward);
    }
    
    /**
     * @dev Fund reward pool
     */
    function fundRewardPool() external payable {
        require(msg.value > 0, "Zero value");
        rewardPool += msg.value;
    }
    
    /**
     * @dev Get user's books
     */
    function getUserBooks(address _user) external view returns (uint256[] memory) {
        return userTokens[_user];
    }
    
    /**
     * @dev Get book details
     */
    function getBookDetails(uint256 _bookId) external view returns (
        string memory title,
        string memory author,
        uint256 pages,
        uint256 price,
        uint256 reward
    ) {
        Book memory book = books[_bookId];
        return (book.title, book.author, book.pages, book.price, book.reward);
    }
}
