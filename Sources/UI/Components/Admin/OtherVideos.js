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

class OtherVideos extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            otherVideos: [],
            metadata: {
                page: 1,
                per: 15,
                total: 0
            }
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch(`/api/admin/otherVideos?page=${this.state.metadata.page}&per=${this.state.metadata.per}`);
        if (response.ok) {
            const otherVideos = await response.json();
            this.setState({ otherVideos: otherVideos.items, metadata: otherVideos.metadata });
        }
    }

    loadPage(page) {
        const metadata = this.state.metadata;
        metadata.page = page;
        this.load();
    }

    render() {
        return (
            <div>
                <h2>Admin <small className="text-muted">Other Videos {this.state.otherVideos.length}</small></h2>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th>Title</th>
                            <th>Source</th>
                            <th>Tags</th>
                            <th className='text-center'># of Subtitles</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.otherVideos.map((otherVideo, i) => {
                            return (<tr key={i}>
                                <td className="align-middle">{otherVideo.title}</td>
                                <td className="align-middle">{otherVideo.source}</td>
                                <td className="align-middle"><div className='d-flex justify-content-between align-items-center'>{otherVideo.tags.map(tag =>
                                    <Badge className='bg-secondary me-1 my-1'>{tag}</Badge>
                                )}</div></td>
                                <td className="align-middle text-center">{otherVideo.count}</td>
                            </tr>);
                        })}
                    </tbody>
                </Table>
                <Pagination totalPages={Math.ceil(this.state.metadata.total / this.state.metadata.per)} currentPage={this.state.metadata.page} showMax={7} onClick={(i) => this.loadPage(i)} />
            </div>
        );
    }
}

export default OtherVideos;