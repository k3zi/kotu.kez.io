import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Pagination from './../react-bootstrap-pagination';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import { ResponsiveLine } from '@nivo/line';

class Decks extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateDeckModal: false,
            showDeleteDeckModal: null,
            users: [],
            metadata: {
                page: 1,
                per: 15,
                total: 0
            },
            usersGroupedByDate: [],
            resetURL: null
        };
    }

    componentDidMount() {
        this.load();
        this.loadNumberOfUsersGroupedByDate();
    }

    async load() {
        const response = await fetch(`/api/admin/users?page=${this.state.metadata.page}&per=${this.state.metadata.per}`);
        if (response.ok) {
            const result = await response.json();
            this.setState({
                users: result.items,
                metadata: result.metadata
            });
        }
    }

    loadPage(page) {
        const metadata = this.state.metadata;
        metadata.page = page;
        this.load();
    }

    async loadNumberOfUsersGroupedByDate() {
        const response = await fetch(`/api/admin/numberOfUsersGroupedByDate`);
        if (response.ok) {
            const result = await response.json();
            const usersGroupedByDate = result.filter(r => r.createdAt).map(r => {
                const oldDate = new Date(r.createdAt);
                const offset = oldDate.getTimezoneOffset();
                const date = new Date(oldDate.getTime() - (offset * 60 * 1000));
                return {
                    x: date,
                    y: r.count
                };
            }).sort((a, b) => a.x - b.x).map(r => {
                return {
                    x: r.x.toISOString().split('T')[0],
                    y: r.y
                }
            });
            this.setState({ usersGroupedByDate });
        }
    }

    async updatePermission(user, permission, value) {
        await fetch(`/api/admin/user/${user.id}/permission/${permission}/${value ? 'true' : 'false'}`, {
            method: 'PUT'
        });
        await this.load();
    }

    async toggleCreateDeckModal(show) {
        this.setState({
            showCreateDeckModal: show
        });
        await this.load();
    }

    async showDeleteDeckModal(deck) {
        this.setState({
            showDeleteDeckModal: deck
        });
        await this.load();
    }

    async resetPassword(user) {
        const response = await fetch(`/api/admin/user/${user.id}/resetPassword`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        const resetKey = await response.text();
        const resetURL = await `${location.origin}/auth/resetPassword/${user.id}/${resetKey}`;
        this.setState({ resetURL });
    }

    render() {
        return (
            <div>
                <h2>Admin <small className="text-muted">User(s) {this.state.metadata.total}</small></h2>
                <hr />
                <div style={{ height: '254px' }}>
                    <ResponsiveLine
                        curve='monotoneX'
                        animate={true}
                        margin={{ top: 10, right: 20, bottom: 10, left: 20 }}
                        data={[{
                                id: 'Users Per Day',
                                data: this.state.usersGroupedByDate
                            }
                        ]}
                        xScale={{
                            type: 'time',
                            format: '%Y-%m-%d',
                            useUTC: false,
                            precision: 'day',
                        }}
                        xFormat="time:%Y-%m-%d"
                        yScale={{
                            type: 'linear',
                            stacked: false,
                        }}
                        axisLeft={{
                            legend: 'Registered Users',
                            legendOffset: 12,
                        }}
                        axisBottom={{
                            format: '%b %d',
                            tickValues: 'every day',
                            legend: 'Day',
                            legendOffset: -12,
                        }}
                        enablePointLabel={true}
                        pointSize={16}
                        pointBorderWidth={1}
                        pointBorderColor={{
                            from: 'color',
                            modifiers: [['darker', 0.3]],
                        }}
                        useMesh={true}
                        enableSlices={false}
                    />
                </div>
                <hr />
                {this.state.resetURL && <Alert dismissible onClose={() => this.setState({ resetURL: null })} className='mt-3' variant='primary'>User Pasword Reset URL: <pre className='mb-0 user-select-all'>{this.state.resetURL}</pre></Alert>}
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th>Username</th>
                            <th className="text-center">Created At</th>
                            <th className="text-center">Admin</th>
                            <th className="text-center">Articles</th>
                            <th className="text-center">API Access</th>
                            <th className="text-center">Subtitles</th>
                            <th className="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.users.map((user, i) => {
                            return (<tr key={i}>
                                <td className="align-middle">{user.username}</td>
                                <td className="align-middle text-center text-success">{user.createdAt}</td>

                                <td className="align-middle text-center">
                                    <Form.Check defaultChecked={user.permissions.includes('admin')} onChange={(e) => this.updatePermission(user, 'admin', e.target.checked)} type="checkbox" />
                                </td>
                                <td className="align-middle text-center">
                                    <Form.Check defaultChecked={user.permissions.includes('blog')} onChange={(e) => this.updatePermission(user, 'blog', e.target.checked)} type="checkbox" />
                                </td>
                                <td className="align-middle text-center">
                                    <Form.Check defaultChecked={user.permissions.includes('api')} onChange={(e) => this.updatePermission(user, 'api', e.target.checked)} type="checkbox" />
                                </td>
                                <td className="align-middle text-center">
                                    <Form.Check defaultChecked={user.permissions.includes('subtitles')} onChange={(e) => this.updatePermission(user, 'subtitles', e.target.checked)} type="checkbox" />
                                </td>
                                <td className="align-middle text-center">
                                    <Button variant="warning" onClick={() => this.resetPassword(user)}><i className="bi bi-arrow-counterclockwise"></i></Button>
                                </td>
                            </tr>);
                        })}
                    </tbody>
                </Table>
                <Pagination totalPages={Math.ceil(this.state.metadata.total / this.state.metadata.per)} currentPage={this.state.metadata.page} showMax={7} onClick={(i) => this.loadPage(i)} />
            </div>
        );
    }
}

export default Decks;
