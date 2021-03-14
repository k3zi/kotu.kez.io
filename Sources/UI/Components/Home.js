import React from 'react';
import UserContext from './Context/User';

import Col from 'react-bootstrap/Col';
import { LinkContainer } from 'react-router-bootstrap';
import ListGroup from 'react-bootstrap/ListGroup';
import Pagination from 'react-bootstrap-4-pagination';
import Row from 'react-bootstrap/Row';

class Component extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            readerSessions: {
                items: [],
                metadata: {
                    page: 1,
                    per: 15,
                    total: 0
                }
            }
        };
    }

    componentDidMount() {
        this.loadReaderSessions();
    }

    async loadReaderSessions() {
        const response = await fetch(`/api/media/reader/sessions?page=${this.state.readerSessions.metadata.page}&per=${this.state.readerSessions.metadata.per}`);
        if (response.ok) {
            const result = await response.json();
            this.setState({ readerSessions: result });
        }
    }

    async loadReaderSessionPage(page) {
        const metadata = this.state.readerSessions.metadata;
        metadata.page = page;
        await this.loadReaderSessions();
    }

    render() {
        return (<UserContext.Consumer>{user => (
            <div>
                <h1>
                    {!user && 'Login / Register to access the rest of the site.'}
                    {user && `Hello ${user.username}!`}
                </h1>

                <Row>
                    {this.state.readerSessions.items.length > 0 && <Col xs={12} lg={6}>
                        <h4>Past Reading Sessions</h4>
                        <ListGroup>
                            {this.state.readerSessions.items.map((s, i) => {
                                return <LinkContainer key={i} to={`/media/reader/${s.id}`}>
                                    <ListGroup.Item action className='d-flex justify-content-between align-items-center text-break text-wrap' style={{ 'white-space': 'normal' }} eventKey={i} >
                                        <div>
                                            <div>
                                                <strong>{s.title || (s.textContent.substring(0, 30) + (s.textContent.length > 30 ? '...' : ''))}</strong>
                                            </div>
                                            <small>{s.title ? (s.textContent.substring(0, 80) + (s.textContent.length > 80 ? '...' : '')) : ''}</small>
                                        </div>
                                    </ListGroup.Item>
                                </LinkContainer>;
                            })}
                        </ListGroup>
                        <Pagination className='mt-3' totalPages={Math.ceil(this.state.readerSessions.metadata.total / this.state.readerSessions.metadata.per)} currentPage={this.state.readerSessions.metadata.page} showMax={7} onClick={(i) => this.loadReaderSessionPage(i)} />
                    </Col>}
                </Row>
            </div>
        )}</UserContext.Consumer>);
    }
}

export default Component;
