import React from 'react';
import UserContext from './Context/User';

class Component extends React.Component {
    render() {
        return (<UserContext.Consumer>{user => (
            <h1>
                {!user && 'Login / Register to access the rest of the site.'}
                {user && `Hello ${user.username}!`}
            </h1>
        )}</UserContext.Consumer>);
    }
}

export default Component;
