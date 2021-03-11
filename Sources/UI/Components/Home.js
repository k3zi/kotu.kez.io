import React from 'react';
import UserContext from './Context/User';

import Col from 'react-bootstrap/Col';
import { LinkContainer } from 'react-router-bootstrap';
import ListGroup from 'react-bootstrap/ListGroup';
import Row from 'react-bootstrap/Row';

class Component extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            readerSessions: []
        };
    }

    componentDidMount() {
        this.loadReaderSessions();
    }

    async loadReaderSessions() {
        const response = await fetch('/api/media/reader/sessions');
        if (response.ok) {
            const result = await response.json();
            this.setState({ readerSessions: result.items });
        }
    }

    render() {
        return (<UserContext.Consumer>{user => (
            <div>
                <h1>
                    {!user && 'Login / Register to access the rest of the site.'}
                    {user && `Hello ${user.username}!`}
                </h1>

                <Row>
                    {this.state.readerSessions.length > 0 && <Col xs={12} lg={6}>
                        <h4>Past Reading Sessions</h4>
                        <ListGroup>
                            {this.state.readerSessions.map((s, i) => {
                                return <LinkContainer key={i} to={`/media/reader/${s.id}`}>
                                    <ListGroup.Item action className='text-break text-wrap' style={{ 'white-space': 'normal' }} eventKey={i} >
                                        <div>
                                            <strong>{s.title || (s.textContent.substring(0, 30) + (s.textContent.length > 30 ? '...' : ''))}</strong>
                                        </div>
                                        <small>{s.title ? (s.textContent.substring(0, 80) + (s.textContent.length > 80 ? '...' : '')) : ''}</small>
                                    </ListGroup.Item>
                                </LinkContainer>;
                            })}
                        </ListGroup>
                    </Col>}
                </Row>
            </div>
        )}</UserContext.Consumer>);
    }
}

export default Component;
