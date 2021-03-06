// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrowdFund {
    struct Campaign {
        address creator;
        uint256 goal;
        uint256 pledged;
        uint32 startAt;
        uint32 endAt;
        bool claimed;
    }

    IERC20 public immutable token;
    uint256 public count;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;

    constructor(address _token) public {
        token = IERC20(_token);
    }

    function launch(
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) public {
        require(
            _startAt > block.timestamp,
            "Campaign cannot start in the past"
        );
        require(_endAt > _startAt, "Campaign cannot end before it starts");
        require(
            _endAt <= block.timestamp + 90 days,
            "Campaign cannot end more than 90 days from now"
        );

        count++;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });
    }

    function cancel(uint256 _id) public {
        Campaign memory campaign = campaigns[_id];
        require(
            campaign.creator == msg.sender,
            "Only the creator can cancel the campaign"
        );
        require(
            campaign.startAt > block.timestamp,
            "Campaign cannot be canceled after it has started"
        );

        delete (campaigns[_id]);
    }

    function pledge(uint256 _id, uint256 _amount) public {
        Campaign storage campaign = campaigns[_id];
        require(
            campaign.startAt <= block.timestamp,
            "Campaign cannot be pledged after it has started"
        );
        require(
            campaign.endAt > block.timestamp,
            "Campaign cannot be pledged after it has ended"
        );

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _id, uint256 _amount) public {
        Campaign storage campaign = campaigns[_id];
        require(
            campaign.endAt > block.timestamp,
            "Campaign cannot be withdrawn after it has ended"
        );
        require(
            _amount <= pledgedAmount[_id][msg.sender],
            "Not enough tokens to withdraw"
        );

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(address(this), _amount);
    }

    function claim(uint256 _id) public {
        Campaign memory campaign = campaigns[_id];
        require(
            campaign.endAt > block.timestamp,
            "Campaign cannot be claimed after it has ended"
        );
        require(campaign.claimed == false, "Campaign has already been claimed");
        require(campaign.goal <= campaign.pledged, "Campaign goal not reached");
        require(msg.sender == campaign.creator, "Only the creator can claim");

        campaign.claimed = true;
        token.transfer(campaign.creator, campaign.pledged);
    }

    function refund(uint256 _id) public {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp >= campaign.endAt, "Campaign has not ended");
        require(campaign.pledged < campaign.goal, "Campaign has not reached goal");
        uint256 bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);
    }
}
