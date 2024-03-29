# mamba-backend-vapor

[![Contributors][contributors-shield]][contributors-url]
[![Stargazers][stars-shield]][stars-url]

<br />
<p align="center">
  <img src="Docs/Mamba.png" alt="Logo" width="120" height="120">
</p>

## Table of Contents

- [About the Project](#about-the-project)
  - [Description](#description)
  - [Built With](#built-with)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
  - [Swift Package Manager](#swift-package-manager)
  - [Docker](#docker)
  - [Commands](#commands)
  - [Error codes](#error-codes)
- [Roadmap](#roadmap)
- [License](#license)
- [Contact](#contact)

## About The Project

### Description

This is the backend companion for [Mamba iOS](https://github.com/Operation-Winter/mamba-ios)

The Mamba project allows a user to host or join a Story Point Planning session and vote on a story.

### Built With

- [Vapor 4.0](https://vapor.codes/)
- [Swift 5.3](https://swift.org/blog/)
- [Swift Package Manager](https://swift.org/package-manager/)
- [Mamba Networking](https://github.com/Operation-Winter/mamba-networking)

## Getting Started

To get a local copy up and running follow these simple example steps.

### Prerequisites

1. XCode 12 Development Tools
2. Install Vapor using brew.

```sh
brew install vapor
```

### Installation

1. Clone the repo

```sh
git clone https://github.com/Operation-Winter/mamba-ios.git
```

2. Open in XCode

## Usage

### Swift Package Manager

Build package:

```sh
swift build
```

Test package:

```sh
swift test
```

Update or resolve package dependencies:

```sh
swift package update
```

### Docker

To run the container:

```sh
docker-compose up
```

### Commands

Commands are sent between the backend and any front-end application using WebSockets.
A command is sent in the following structure:

```json
{
  "uuid": "<Front-End UUID>",
  "type": "<Command identifier>",
  "message": {} //Contains the message body structure as specified below or null
}
```

#### Planning Sequence Diagram

![Planning Command Sequence](Docs/Planning_commands.png)

---

#### Planning Host

##### Client to server

<table>
  <tr>
    <th>
        Type
    </th>
    <th>
        Description
    </th>
    <th>
        Message
    </th>
  </tr>
  <tr>
    <td>
      <pre>START_SESSION</pre>
    </td>
    <td>
      Send session name and available cards.
    </td>
    <td>
      <pre lang="json">
{ 
  "sessionName": "Example session", 
  "availableCards": [
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "autoCompleteVoting": true,
  "tags": ["iOS", "Android"],
  "password": "Bacon", // optional

}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>ADD_TICKET</pre>
    </td>
    <td>
      Add a new ticket. Changes state to `VOTING`
    </td>
    <td>
      <pre lang="json">
{ 
  "title": "DM-10000", 
  "description": "Blah blah",
  "selectedTags":["iOS", "Android"]
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>SKIP_VOTE</pre>
    </td>
    <td>
      Skip vote for a participant
    </td>
    <td>
      <pre lang="json">
{ 
  "participantId": ""
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>REMOVE_PARTICIPANT</pre>
    </td>
    <td>
      Request to remove a participant from the session
    </td>
    <td>
      <pre lang="json">
{ 
  "participantId": ""
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>END_SESSION</pre>
    </td>
    <td>
      Closes session and removes all participants
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>FINISH_VOTING</pre>
    </td>
    <td>
      Force state from `VOTING` to `VOTING_FINISHED`
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>REVOTE</pre>
    </td>
    <td>
      When in `VOTING_FINISHED` state revote the current ticket
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>RECONNECT</pre>
    </td>
    <td>
      Reconnect to existing session using a UUID
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>EDIT_TICKET</pre>
    </td>
    <td>
      Edit the details of the existing ticket
    </td>
    <td>
      <pre lang="json">
{ 
  "title": "DM-10000", 
  "description": "Blah blah",
  "selectedTags":["iOS", "Android"]
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>ADD_TIMER</pre>
    </td>
    <td>
      Add a timer to the session to end voting when the timer ends.
    </td>
    <td>
    <pre lang="json">
{ 
  "time":2
}</pre>
    </td>
  </tr>
    <tr>
    <td>
      <pre>CANCEL_TIMER</pre>
    </td>
    <td>
      Cancel an active timer.
    </td>
    <td>
      None
    </td>
  </tr>
  </tr>
    <tr>
    <td>
      <pre>PREVIOUS_TICKETS</pre>
    </td>
    <td>
      Request previous tickets that have been voted on.
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>REQUEST_COFFEE_BREAK</pre>
    </td>
    <td>
      Request coffee break break.
    </td>
    <td>
      None
    </td>
  </tr>
</table>

##### Server to client

<table>
  <tr>
    <th>
        Type
    </th>
    <th>
        Description
    </th>
    <th>
        Message
    </th>
  </tr>
  <tr>
    <td>
      <pre>NONE_STATE</pre>
    </td>
    <td>
      State `NONE` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    }
  ],
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>VOTING_STATE</pre>
    </td>
    <td>
      State `VOTING` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    },
    {
      "name":"Piet",
      "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515"
    }
  ],
  "ticket":{
    "title":"Test",
    "ticketVotes":[
      {
        "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9",
        "selectedCard":"FIVE",
        "tag":"iOS"
      }
    ],
    "description":"Test"
  },
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>FINISHED_STATE</pre>
    </td>
    <td>
      State `VOTING_FINISHED` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    },
    {
      "name":"Piet",
      "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515"
    }
  ],
  "ticket":{
    "title":"Test",
    "ticketVotes":[
      {
        "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9",
        "selectedCard":"FIVE"
        "tag":"iOS"
      },
      {
        "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515",
        "selectedCard":null, //Indicates that this vote is skipped
        "tag":null
      }
    ],
    "description":"Test"
  },
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>INVALID_COMMAND</pre>
    </td>
    <td>
      Inform client that command sent is invalid
    </td>
    <td>
      <pre lang="json">
{
  "code":"0000",
  "description":"No session code has been specified"
}</pre>
    </td>
  </tr>
  </tr>
    <tr>
    <td>
      <pre>PREVIOUS_TICKETS</pre>
    </td>
    <td>
      Response that contains previous tickets that have been voted on.
    </td>
    <td>
        <pre lang="json">
{
  "previousTickets":[
    { 
      "title":"Test",
      "ticketVotes":[
        {
          "participantId":"D520EFDD-C4BD-450B-9531-30E404B77D0F",
          "selectedCard":"FIVE",
          "tag":"iOS"
          }
        ],
      "description":""
    }
  ]
}</pre>
        </td>
    </tr>
    <tr>
        <td>
          <pre>SESSION_IDLE_TIMEOUT</pre>
        </td>
        <td>
          Response that indicates that the session has timed out because it was idle.
        </td>
        <td>
        </td>
    </tr>
</table>

#### Planning Join

##### Client to server

<table>
  <tr>
    <th>
        Type
    </th>
    <th>
        Description
    </th>
    <th>
        Message
    </th>
  </tr>
  <tr>
    <td>
      <pre>JOIN_SESSION</pre>
    </td>
    <td>
      Join session with specified sessionCode, user name, and password.
    </td>
    <td>
      <pre lang="json">
{
  "participantName":"Armand",
  "sessionCode":"545544",
  "password":"Bacon" //optional
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>VOTE</pre>
    </td>
    <td>
      Send vote value for a ticket
    </td>
    <td>
      <pre lang="json">
{
  "selectedCard":"ONE",
  "tag":"iOS"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>LEAVE_SESSION</pre>
    </td>
    <td>
      Inform server client is disconnecting
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>RECONNECT</pre>
    </td>
    <td>
      Reconnect to existing session using a UUID
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>CHANGE_NAME</pre>
    </td>
    <td>
      Change participant's name. Will fail if not the matching participant UUID.
    </td>
    <td>
    <pre lang="json">
{
  "name":"TestName"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>REQUEST_COFFEE_BREAK</pre>
    </td>
    <td>
      Request coffee break break.
    </td>
    <td>
      None
    </td>
  </tr>
</table>

##### Server to client

<table>
  <tr>
    <th>
        Type
    </th>
    <th>
        Description
    </th>
    <th>
        Message
    </th>
  </tr>
  <tr>
    <td>
      <pre>NONE_STATE</pre>
    </td>
    <td>
      State `NONE` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    }
  ],
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>VOTING_STATE</pre>
    </td>
    <td>
      State `VOTING` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    },
    {
      "name":"Piet",
      "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515"
    }
  ],
  "ticket":{
    "title":"Test",
    "ticketVotes":[
      {
        "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9",
        "selectedCard":"FIVE",
        "tag":"iOS"
      }
    ],
    "description":"Test"
  },
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>FINISHED_STATE</pre>
    </td>
    <td>
      State `VOTING_FINISHED` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    },
    {
      "name":"Piet",
      "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515"
    }
  ],
  "ticket":{
    "title":"Test",
    "ticketVotes":[
      {
        "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9",
        "selectedCard":"FIVE",
        "tag":"iOS"
      },
      {
        "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515",
        "selectedCard":null, //Indicates that this vote is skipped
        "tag": null
      }
    ],
    "description":"Test"
  },
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>INVALID_COMMAND</pre>
    </td>
    <td>
      Inform client that command sent is invalid
    </td>
    <td>
      <pre lang="json">
{
  "code":"0000",
  "description":"No session code has been specified"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>INVALID_SESSION</pre>
    </td>
    <td>
      Inform client that session is invalid
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>REMOVE_PARTICIPANT</pre>
    </td>
    <td>
      Inform client that they have been removed from the session
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>END_SESSION</pre>
    </td>
    <td>
      Inform client that session had been ended
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>SESSION_IDLE_TIMEOUT</pre>
    </td>
    <td>
      Response that indicates that the session has timed out because it was idle.
    </td>
    <td>
    </td>
  </tr>
</table>

#### Planning Spectate

##### Client to server

<table>
  <tr>
    <th>
        Type
    </th>
    <th>
        Description
    </th>
    <th>
        Message
    </th>
  </tr>
  <tr>
    <td>
      <pre>JOIN_SESSION</pre>
    </td>
    <td>
      Send session code and password
    </td>
    <td>
      <pre lang="json">
{
  "password":"Bacon",
  "sessionCode":"545544"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>LEAVE_SESSION</pre>
    </td>
    <td>
      Inform server client is disconnecting
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>RECONNECT</pre>
    </td>
    <td>
      Reconnect to existing session using a UUID
    </td>
    <td>
      None
    </td>
  </tr>
</table>

##### Server to client

<table>
  <tr>
    <th>
        Type
    </th>
    <th>
        Description
    </th>
    <th>
        Message
    </th>
  </tr>
  <tr>
    <td>
      <pre>NONE_STATE</pre>
    </td>
    <td>
      State `NONE` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    }
  ],
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>VOTING_STATE</pre>
    </td>
    <td>
      State `VOTING` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    },
    {
      "name":"Piet",
      "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515"
    }
  ],
  "ticket":{
    "title":"Test",
    "ticketVotes":[
      {
        "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9",
        "selectedCard":"FIVE",
        "tag":"iOS"
      }
    ],
    "description":"Test"
  },
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>FINISHED_STATE</pre>
    </td>
    <td>
      State `VOTING_FINISHED` command containing current state of session
    </td>
    <td>
      <pre lang="json">
{
  "participants":[
    {
      "name":"Armand",
      "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9"
    },
    {
      "name":"Piet",
      "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515"
    }
  ],
  "ticket":{
    "title":"Test",
    "ticketVotes":[
      {
        "participantId":"852ACB12-4B40-4BC2-B72B-17057A1A5AE9",
        "selectedCard":"FIVE",
        "tag":"iOS"
      },
      {
        "participantId":"34ED510B-B21D-423E-83D0-B85747F4D515",
        "selectedCard":null, //Indicates that this vote is skipped
        "tag":null
      }
    ],
    "description":"Test"
  },
  "availableCards":[
    "ZERO", "ONE", "TWO", "THREE", "FIVE", "EIGHT", "THIRTEEN", "TWENTY", "FOURTY", "HUNDRED", "QUESTION"
  ],
  "sessionCode":"000000",
  "sessionName":"Test"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>INVALID_COMMAND</pre>
    </td>
    <td>
      Inform client that command sent is invalid
    </td>
    <td>
      <pre lang="json">
{
  "code":"0000",
  "description":"No session code has been specified"
}</pre>
    </td>
  </tr>
  <tr>
    <td>
      <pre>INVALID_SESSION</pre>
    </td>
    <td>
      Inform client that session is invalid
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>END_SESSION</pre>
    </td>
    <td>
      Inform client that session had been ended
    </td>
    <td>
      None
    </td>
  </tr>
  <tr>
    <td>
      <pre>SESSION_IDLE_TIMEOUT</pre>
    </td>
    <td>
      Response that indicates that the session has timed out because it was idle.
    </td>
    <td>
    </td>
  </tr>
</table>

### Error codes

#### Invalid Session

- `0001`: The specified session code doesn't exist or the password provided is invalid.

#### Invalid Command

- `0000`: No session code has been specified.
- `0002`: The command doesn't exist.
- `0003`: The server has run out of capacity, could not create a new planning session.
- `0004`: Invalid identifier.
- `0005`: Invalid parameters.
- `0006`: Invalid state.

#### Session timeout
- `0007`: Session idle timeout

## Roadmap

White lines indicate completed features.

[![Roadmap][roadmap]](Docs/Roadmap.png)

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Armand Kamffer - [@Armgame](https://twitter.com/Armgame) - kamffer1@gmail.com

[contributors-shield]: https://img.shields.io/github/contributors/Operation-Winter/mamba-backend-vapor?style=flat-square
[contributors-url]: https://github.com/Operation-Winter/mamba-backend-vapor/graphs/contributors
[stars-shield]: https://img.shields.io/github/stars/Operation-Winter/mamba-backend-vapor?style=flat-square?style=flat-square
[stars-url]: https://github.com/Operation-Winter/mamba-backend-vapor/stargazers
[roadmap]: Docs/Roadmap.png
