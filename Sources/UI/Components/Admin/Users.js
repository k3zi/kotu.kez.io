import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

class Decks extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateDeckModal: false,
            showDeleteDeckModal: null,
            users: [],
            invites: [],
            resetURL: null
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch('/api/admin/users');
        if (response.ok) {
            const users = await response.json();
            this.setState({ users });
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
        this.setState({ resetURL })
    }

    render() {
        return (
            <div>
                <h2>Admin <small className="text-muted">User(s) {this.state.users.length}</small></h2>
                {this.state.resetURL && <Alert dismissible onClose={() => this.setState({ resetURL: null })} className='mt-3' variant='primary'>User Pasword Reset URL: <pre className='mb-0 user-select-all'>{this.state.resetURL}</pre></Alert>}
                <hr/>
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
            </div>
        );
    }
}

export default Decks;
