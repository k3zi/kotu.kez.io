import React from 'react';
import ColorSchemeContext from './Context/ColorScheme';
import UserContext from './Context/User';

import Col from 'react-bootstrap/Col';
import { LinkContainer } from 'react-router-bootstrap';
import ListGroup from 'react-bootstrap/ListGroup';
import Pagination from './react-bootstrap-pagination';
import Row from 'react-bootstrap/Row';

import { ResponsiveCalendar } from '@nivo/calendar';
import { ResponsiveBar } from '@nivo/bar';

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
            },
            reviewLogs: [],
            reviewsGroupedByGrade: []
        };
    }

    componentDidMount() {
        this.loadReaderSessions();
        this.loadReviewLogs();
        this.loadReviewCountByGrade();
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

    async loadReviewLogs() {
        const response = await fetch('/api/flashcard/groupedLogs');
        if (response.ok) {
            const result = await response.json();
            const reviewLogs = result.map(r => {
                const oldDate = new Date(r.groupDate);
                const offset = oldDate.getTimezoneOffset();
                const date = new Date(oldDate.getTime() - (offset * 60 * 1000));
                return {
                    value: r.count,
                    day: date.toISOString().split('T')[0]
                };
            });
            this.setState({ reviewLogs });
        }
    }

    async loadReviewCountByGrade() {
        const response = await fetch('/api/flashcard/numberOfReviewsGroupedByGrade');
        if (response.ok) {
            const reviewsGroupedByGrade = await response.json();
            this.setState({ reviewsGroupedByGrade });
        }
    }

    render() {
        return (<UserContext.Consumer>{user => (
            (<ColorSchemeContext.Consumer>{colorScheme => (
                <div>
                    <h1 className='mb-0'>
                        {!user && 'Login / Register to access the rest of the site.'}
                        {user && `Hello ${user.username}!`}
                    </h1>
                    {user && <div className='mb-2'><strong>Quick Links:</strong>
                        {' '}
                        <LinkContainer to='/media/reader'>
                            <a href='#' className='text-decoration-none'>Reader</a>
                        </LinkContainer>
                        ・
                        <LinkContainer to='/media/youtube'>
                            <a href='#' className='text-decoration-none'>YouTube</a>
                        </LinkContainer>
                        ・
                        <LinkContainer to='/search'>
                            <a href='#' className='text-decoration-none'>Advanced Search</a>
                        </LinkContainer>
                    </div>}

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

                        {(this.state.reviewLogs.length > 0 || this.state.reviewsGroupedByGrade.length > 0) && <Col xs={12} lg={6}>
                            {this.state.reviewLogs.length > 0 && <div>
                                <h4>Anki Review History</h4>
                                <div style={{ height: '127px' }}>
                                    <ResponsiveCalendar
                                        data={this.state.reviewLogs}
                                        from={new Date(new Date().getFullYear(), 0, 1)}
                                        to={new Date()}
                                        emptyColor="#ebedf0"
                                        colors={[ '#9be9a8', '#40c463', '#30a14e', '#216e39' ]}
                                        monthBorderColor={colorScheme == 'dark' ? '#272727' : '#ffffff'}
                                        dayBorderWidth={2}
                                        dayBorderColor={colorScheme == 'dark' ? '#272727' : '#ffffff'}
                                        theme={{
                                            textColor: colorScheme == 'dark' ? 'var(--bs-light)' : 'var(--bs-dark)',
                                            tooltip: {
                                                container: {
                                                    color: 'var(--bs-dark)'
                                                }
                                            }
                                        }}
                                        legends={[
                                            {
                                                anchor: 'bottom-right',
                                                direction: 'row',
                                                translateY: 36,
                                                itemCount: 4,
                                                itemWidth: 42,
                                                itemHeight: 36,
                                                itemsSpacing: 14,
                                                itemDirection: 'right-to-left'
                                            }
                                        ]}
                                    />
                                </div>
                            </div>}
                            {this.state.reviewsGroupedByGrade.length > 0 && <div>
                                <h4>Anki Grading Spread</h4>
                                <div style={{ height: '127px' }}>
                                    <ResponsiveBar
                                        data={this.state.reviewsGroupedByGrade}
                                        keys={[ 'count' ]}
                                        indexBy="grade"
                                        padding={0.3}
                                        axisTop={null}
                                        axisRight={null}
                                        axisBottom={{
                                            tickSize: 5,
                                            tickPadding: 5,
                                            tickRotation: 0,
                                            legend: 'Grade',
                                            legendPosition: 'middle',
                                            legendOffset: 32
                                        }}
                                        axisLeft={{
                                            tickSize: 5,
                                            tickPadding: 5,
                                            tickRotation: 0,
                                            legend: 'Count',
                                            legendPosition: 'middle',
                                            legendOffset: -40
                                        }}
                                        labelSkipWidth={12}
                                        labelSkipHeight={12}
                                        labelTextColor={{ from: 'color', modifiers: [ [ 'darker', 1.6 ] ] }}
                                        legends={[
                                            {
                                                dataFrom: 'keys',
                                                anchor: 'bottom-right',
                                                direction: 'column',
                                                justify: false,
                                                translateX: 120,
                                                translateY: 0,
                                                itemsSpacing: 2,
                                                itemWidth: 100,
                                                itemHeight: 20,
                                                itemDirection: 'left-to-right',
                                                itemOpacity: 0.85,
                                                symbolSize: 20,
                                                effects: [
                                                    {
                                                        on: 'hover',
                                                        style: {
                                                            itemOpacity: 1
                                                        }
                                                    }
                                                ]
                                            }
                                        ]}
                                        animate={true}
                                        motionStiffness={90}
                                        motionDamping={15}
                                    />
                                </div>
                            </div>}
                        </Col>}


                    </Row>
                </div>
            )}</ColorSchemeContext.Consumer>)
        )}</UserContext.Consumer>);
    }
}

export default Component;
