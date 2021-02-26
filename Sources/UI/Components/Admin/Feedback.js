import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

class Feedback extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            feedback: []
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch('/api/admin/feedback');
        if (response.ok) {
            const feedback = await response.json();
            this.setState({ feedback });
        }
    }

    render() {
        return (
            <div>
                <h2>Admin <small className="text-muted">Feedback {this.state.feedback.length}</small></h2>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Text</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.feedback.map((feedback, i) => {
                            return (<tr key={i}>
                                <td className="align-middle text-center text-success">{feedback.createdAt}</td>
                                <td className="align-middle">{feedback.value}</td>
                            </tr>);
                        })}
                    </tbody>
                </Table>
            </div>
        );
    }
}

export default Feedback;
